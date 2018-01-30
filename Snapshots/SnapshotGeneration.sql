/*---------------------------------------------------------------------

Author:		Justin Goodwin, https://sqljgood.wordpress.com/
				https://twitter.com/GoodwinSQL

Date:		June 2nd, 2016

NOTES:		For now, this places the snapshot files (.ss) in the 
			same location as the original database files. The 
			command can be tweaked once it is generated if the 
			location needs to be changed.
			
Blog Post:  https://sqljgood.wordpress.com/2016/06/02/easily-generate-sql-server-database-snapshot-create-statements/

			
  You may alter this code for your own *non-commercial* purposes. 
  You may republish altered code as long as you give due credit. 
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

-----------------------------------------------------------------------*/

use master
go

set nocount on; --remove '(x row(s) affected)' garbage

declare @Target_DB varchar(200) 
declare @Snap_Desc varchar(100) 

declare @Snap_Name varchar(300)

declare @Snap_Script varchar(max)
declare @File_Count_Script varchar(max)
declare @File_Count int

declare @filename varchar(100)
declare @physical_name varchar(300)
declare @cursorcount int
declare @cursorscript varchar(max)


/*--------SET THE VARIABLES HERE-----------------*/
--target database of which you are going to take the snapshot
set @Target_DB = 'Database_Name'

--description or purpose of the snapshot (to make the snapshot name somewhat descriptive)
set @Snap_Desc = 'Pre_Database_Upgrade_' + CONVERT(varchar,GETDATE(), 114)

--Combining @Target_DB and @Snap_Desc to create a snapshot name. 
	--This can be changed to whatever you wish.
set @Snap_Name = @Target_DB + '_' + @Snap_Desc + '_ss'

/*-----------------------------------------------*/

--check if the @Target_DB exists on the current server
IF NOT EXISTS(select 1 from sys.databases where name = @Target_DB)
	Begin
	Print '@Target_DB ' + @Target_DB + ' does not exist on the server! Double Check the @Target_DB name.'
	GOTO FINISH
	End


print '--Snapshot Name: ' + @Snap_Name


--create 2 temp holding tables
	if OBJECT_ID(N'tempdb..#tempcount') is not null
	begin
		drop table #tempcount
	end
	
	create table #tempcount (count int)
	
	if OBJECT_ID(N'tempdb..#tempcursor') is not null
	begin
		drop table #tempcursor
	end
	
	create table #tempcursor (
		name sysname
		,physical_name nvarchar(260)
		)

--determining how many DB data files exist for @Target_DB
set @File_Count_Script = '
select COUNT(name)
from ' + QUOTENAME(@Target_DB) + '.sys.database_files
where type = 0 --Rows only
'
--by doing this insert..exec into a temp table, we can avoid having to be connected to the target_db
insert into #tempcount
exec (@File_Count_Script)

select @File_Count = count
from #tempcount

print '--Number of DB Files: ' + CAST(@File_Count as varchar(3)) + '

'

set @cursorcount = 1 --the iterative loop counter

--begin creation of the create snapshot script here...
set @Snap_Script = 'USE master; 
CREATE DATABASE ' + QUOTENAME(@Snap_Name) + ' ON 
 '

--if there is more than 1 database data file, we will need to iterate through each file....cursor time.
set @cursorscript = '
select name
	,physical_name
from ' + QUOTENAME(@Target_DB) + '.sys.database_files
where type = 0 --Rows only
'

--more insert..exec...
insert into #tempcursor
exec (@cursorscript)

declare file_name_cursor cursor
for
select name
	,physical_name
from #tempcursor

--start cursor
open file_name_cursor

fetch next
from file_name_cursor
into @filename
	,@physical_name

while @@fetch_status = 0
begin
	if (@cursorcount > 1) --we need a leading comma for each new file after the first file
	begin
		set @Snap_Script = @Snap_Script + '
,'
	end
	--add each DB data file to the snapshot command being built
	set @Snap_Script = @Snap_Script + '( NAME = ' + QUOTENAME(@filename) + ', 
		FILENAME = ''' + REPLACE((REPLACE(@physical_name, '.mdf', '.ss')), '.ndf', '.ss') + ''')' --replace .mdf or .ndf with .ss


	set @cursorcount = @cursorcount + 1 --add to the loop counter after each data file

	fetch next
	from file_name_cursor
	into @filename
		,@physical_name
end

close file_name_cursor

deallocate file_name_cursor

--add the final piece to the snapshot create statement and build the snapshot revert statement
set @Snap_Script = @Snap_Script + '
AS SNAPSHOT of ' + QUOTENAME(@Target_DB) + ';



/*--------SNAPSHOT Revert Script------------/

USE master;  
--ALTER DATABASE '+QUOTENAME(@Target_DB)+' SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;

-- Reverting DB '+QUOTENAME(@Target_DB)+' to '+QUOTENAME(@Snap_Name)+'  
RESTORE DATABASE '+QUOTENAME(@Target_DB)+' from   
DATABASE_SNAPSHOT = '''+@Snap_Name+''';  
GO

/-------------------------------------------*/

'
--output the commands that we have built
print @Snap_Script

--cleanup temp tables
drop table #tempcount
drop table #tempcursor

FINISH: --if there is an error, skip to this label
