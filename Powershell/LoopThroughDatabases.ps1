<#

Blogged about here: https://sqljgood.wordpress.com/2014/09/17/using-powershell-to-loop-through-a-list-of-sql-server-databases/

Pre Req Table. We query this table to grab our list of Servers & Databases to iterate through

CREATE TABLE [dbo].[SQL_DATABASES](
    [INSTANCE] [varchar](50) NOT NULL,
    [DATABASENAME] [varchar](100) NOT NULL,
    [REGION] [varchar](4) NOT NULL)

#>



# NOTE* It is always best to test any process on a single dev or test server before trying it on ALL production databases!
# ----------------------------------------------
Import-Module SqlPs -DisableNameChecking #may only need this line for SQL 2012 +
 
# $databases grabs list of production databases from the SQL_DATABASES table on your Database
$databases = invoke-sqlcmd -ServerInstance Server -Database Database -Query "SELECT INSTANCE, DATABASENAME FROM Database.dbo.SQL_DATABASES WHERE REGION = 'PROD'"
 
 
foreach ($database in $databases) #for each separate server / database pair in $databases
{
# This lets us pick out each instance ($inst) and database ($name) as we iterate through each pair of server / database.
$Inst = $database.INSTANCE #instance from the select query
$DBname = $database.DATABASENAME #databasename from the select query
 
 
#generate the output file name for each server/database pair
$filepath = "C:\DBA_SCRIPTS\"
$filename = $Inst +"_"+ $DBname +"_FileSuffix.sql" #Modify the FileSuffix as you see fit
  
# This line can be used if there are named instances in your environment.
# $filename = $filename.Replace("\","$") # Replaces all "\" with "$" so that instance name can be used in file names.
  
$outfile = ($filepath + $filename) #create out-file file name
 
 
#connect to each instance\database and generate script and output to files
invoke-sqlcmd -ServerInstance ${Inst} -Database ${DBname} -InputFIle "C:\DBA_SCRIPTS\InputQueryFile.sql" | out-file -filepath ($outfile)
  
} #end foreach loop