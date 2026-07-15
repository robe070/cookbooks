<#
.SYNOPSIS
    Create the web login/user in Azure SQL Database after the LANSA MSI install.

.DESCRIPTION
    Azure SQL Database rejects the `CREATE LOGIN ... DEFAULT_DATABASE=` clause that the
    LANSA installer emits (native error 40517), so the SUDB=1 database setup cannot create
    the web login/user itself. SUDB=1 must stay (it creates the application tables); this
    script performs the login/user creation the installer could not, and MUST run AFTER the
    MSI install has created the database and tables.

    Equivalent T-SQL (run against the Azure SQL server named by $ServerName):
        -- in master:
        CREATE LOGIN [<WebUser>] WITH PASSWORD = '<WebPassword>';
        -- in <DatabaseName>:
        CREATE USER [<WebUser>] FOR LOGIN [<WebUser>];
        ALTER ROLE db_owner ADD MEMBER [<WebUser>];   -- (sp_addrolemember equivalent)

    Identifiers/passwords are passed as parameters and quoted server-side with QUOTENAME,
    so there are no literals and no injection risk. Every statement is guarded so the
    script is idempotent across all deployments and re-runs.

.EXAMPLE
    ./create-azure-sql-login.ps1 -deploymentOutput '$(deploymentOutput)' `
        -AdminUser "$(databaseLogin)" -AdminPassword "$(databaseLoginPassword)" `
        -WebUser "$(webUsername)" -WebPassword "$(webPassword)"
#>
param(
    [Parameter(Mandatory=$true)][string]$deploymentOutput, # ARM deploymentOutput JSON; supplies dbServerName + dbName
    [Parameter(Mandatory=$true)][string]$AdminUser,        # Azure SQL admin login, e.g. testsrv-dp ($(databaseLogin))
    [Parameter(Mandatory=$true)][string]$AdminPassword,    # Azure SQL admin password ($(databaseLoginPassword))
    [Parameter(Mandatory=$true)][string]$WebUser,          # login/user to create, e.g. PCXUSER2 ($(webUsername))
    [Parameter(Mandatory=$true)][string]$WebPassword,      # password for the login ($(webPassword))
    [Parameter(Mandatory=$false)][int]$Port = 1433
)

$ErrorActionPreference = 'Stop'

# Pull the SQL server FQDN and database name straight from the ARM deployment output
# (same object azure_url_tests.ps1 reads lbFqdn from), so nothing is hard-coded.
$output = ConvertFrom-Json $deploymentOutput
$ServerName   = $output.dbServerName.value   # e.g. w19d160bnsqlserver.database.windows.net
$DatabaseName = $output.dbName.value         # e.g. lansa

if ([string]::IsNullOrWhiteSpace($ServerName))   { throw "deploymentOutput did not contain dbServerName.value" }
if ([string]::IsNullOrWhiteSpace($DatabaseName)) { throw "deploymentOutput did not contain dbName.value" }

# Execute a parameterised batch against a specific database on the Azure SQL server.
# A fresh connection is opened per database because Azure SQL does not support USE <db>.
function Invoke-AzureSqlNonQuery {
    param(
        [string]$Database,
        [string]$Sql,
        [hashtable]$SqlParameters
    )

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Server']              = "tcp:$ServerName,$Port"
    $builder['Initial Catalog']     = $Database
    $builder['User ID']             = $AdminUser
    $builder['Password']            = $AdminPassword
    $builder['Encrypt']             = $true      # required by Azure SQL Database
    $builder['TrustServerCertificate'] = $true
    $builder['Connect Timeout']     = 60

    $connection = New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Sql
        $command.CommandTimeout = 120
        foreach ($name in $SqlParameters.Keys) {
            [void]$command.Parameters.AddWithValue($name, $SqlParameters[$name])
        }
        [void]$command.ExecuteNonQuery()
    }
    finally {
        $connection.Dispose()
    }
}

Write-Host "Creating web login '$WebUser' on $ServerName (db '$DatabaseName') ..."

# 1. CREATE LOGIN in master (guarded; QUOTENAME brackets the identifier and single-quotes/escapes the password).
$createLogin = @"
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = @user)
BEGIN
    DECLARE @sql nvarchar(max) =
        N'CREATE LOGIN ' + QUOTENAME(@user) + N' WITH PASSWORD = ' + QUOTENAME(@pwd, '''') + N';';
    EXEC sys.sp_executesql @sql;
END
"@
Invoke-AzureSqlNonQuery -Database 'master' -Sql $createLogin `
    -SqlParameters @{ '@user' = $WebUser; '@pwd' = $WebPassword }
Write-Host "  master: login ensured."

# 2. CREATE USER in the application database (guarded).
$createUser = @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @user)
BEGIN
    DECLARE @sql nvarchar(max) =
        N'CREATE USER ' + QUOTENAME(@user) + N' FOR LOGIN ' + QUOTENAME(@user) + N';';
    EXEC sys.sp_executesql @sql;
END
"@
Invoke-AzureSqlNonQuery -Database $DatabaseName -Sql $createUser `
    -SqlParameters @{ '@user' = $WebUser }
Write-Host "  $($DatabaseName): user ensured."

# 3. Add the user to db_owner (guarded). ALTER ROLE is the current form of sp_addrolemember.
$addRole = @"
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members rm
    JOIN sys.database_principals r ON rm.role_principal_id   = r.principal_id
    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
    WHERE r.name = N'db_owner' AND m.name = @user)
BEGIN
    DECLARE @sql nvarchar(max) = N'ALTER ROLE db_owner ADD MEMBER ' + QUOTENAME(@user) + N';';
    EXEC sys.sp_executesql @sql;
END
"@
Invoke-AzureSqlNonQuery -Database $DatabaseName -Sql $addRole `
    -SqlParameters @{ '@user' = $WebUser }
Write-Host "  $($DatabaseName): db_owner membership ensured."

Write-Host "Web login '$WebUser' is ready."
