/*********************************/
/* Execute this script in sections delimited by the comment line above */
/* Select the section and type F5 */

USE master
GO

ALTER DATABASE PAAS 
SET SINGLE_USER 
WITH ROLLBACK IMMEDIATE
GO

EXEC master..sp_renamedb 'PAAS','PAASOLD'
GO

ALTER DATABASE PAASOLD 
SET MULTI_USER 
GO

/*********************************/

/* Set Database as a Single User */
ALTER DATABASE PAASOLD SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO

/* Change Logical File Names */
ALTER DATABASE PAASOLD MODIFY FILE (NAME=N'PAAS', NEWNAME=N'PAASOLD')
GO

ALTER DATABASE PAASOLD MODIFY FILE (NAME=N'PAAS_log', NEWNAME=N'PAASOLD_log')
GO

/*********************************/

USE [master]
GO

EXEC master.dbo.sp_detach_db @dbname = N'PAASOLD'
GO

/*********************************/
/*********************************/

/* N.B. Rename physical files using Windows Explorer */
/* e.g. C:\Program Files\Microsoft SQL Server\MSSQL13.SQL2016\MSSQL\DATA\PAAS.mdf to */
/* C:\Program Files\Microsoft SQL Server\MSSQL13.SQL2016\MSSQL\DATA\PAASOLD.mdf	     */
/* and C:\Program Files\Microsoft SQL Server\MSSQL13.SQL2016\MSSQL\DATA\PAAS_log.mdf to */
/* C:\Program Files\Microsoft SQL Server\MSSQL13.SQL2016\MSSQL\DATA\PAASOLD_log.mdf	     */

/*********************************/
/*********************************/

/* Attach Renamed PAASOLD Database Online */
USE [master]
GO

CREATE DATABASE PAASOLD ON 
( FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.SQL2016\MSSQL\DATA\PAASOLD.mdf' ),
( FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.SQL2016\MSSQL\DATA\PAASOLD_log.ldf' )
FOR ATTACH
GO

/* Set Database to Multi User*/
ALTER DATABASE PAASOLD SET MULTI_USER 
GO

USE master
GO
/*********************************/

/* Identify Database File Names */
SELECT 
name AS [Logical Name], 
physical_name AS [DB File Path],
type_desc AS [File Type],
state_desc AS [State] 
FROM sys.master_files
WHERE database_id = DB_ID(N'PAASOLD')
GO