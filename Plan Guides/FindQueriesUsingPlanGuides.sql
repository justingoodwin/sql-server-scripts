--Could take a while to execute on a server with a large plan cache, be patient
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT qt.text
	,DB_NAME(qt.dbid) AS db_name
	,LEFT(SUBSTRING(CAST(qp.query_plan AS nvarchar(max)), CHARINDEX('PlanGuideName', 
	CAST(qp.query_plan AS nvarchar(max))) + 15, 100), 
	CHARINDEX('"', SUBSTRING(CAST(qp.query_plan AS nvarchar(max)), 
	CHARINDEX ('PlanGuideName', CAST(qp.query_plan AS nvarchar(max))) + 16, 100))) AS PlanGuideName
	,qs.total_logical_reads / qs.execution_count AS [Avg Logical Reads]
	,qs.total_elapsed_time / qs.execution_count / 1000 AS [Avg Elapsed ms]
	,qs.execution_count
	,qs.last_execution_time
	,qs.creation_time as Compile_Time
	,qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE CAST(qp.query_plan AS nvarchar(max)) LIKE ('%PlanGuideName%')
	AND qt.text NOT LIKE '%sys.dm%' --filter out any DBA user queries that may be hitting system tables
ORDER BY qs.last_execution_time desc
OPTION (RECOMPILE, MAXDOP 1);--prevent this query from filling the cache & try to minimize it's cpu impact


SET TRANSACTION ISOLATION LEVEL READ COMMITTED;