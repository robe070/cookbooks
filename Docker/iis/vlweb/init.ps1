param(
    [String]$server_name='xrobertpc\sqlserver2012',
    [String]$dbname='test1',
    [String]$dbuser = 'admin',
    [String]$dbpassword = 'password',
    [String]$webuser = 'PCXUSER2',
    [String]$webpassword = 'PCXUSER@122',
    [String]$f32bit = 'true',
    [String]$SUDB = '1',
    [String]$maxconnections = '20',
    [String]$userscripthook,
    [Parameter(Mandatory=$false)]
    [String]$DBUT='MSSQLS',
    [String]$MSIuri
)

Get-ChildItem c:\
Write-Host "GITREPOPATH: $ENV:GITREPOPATH";
Set-Location $ENV:GITREPOPATH
Get-ChildItem
git pull

# Change the tempdir to the host volume so log files can be seen on the host
# In order to view installation logs, when running the container specify the VOLUME option (-v h:\temp\c:\temp\) which creates the directory
# c:\temp. But if the option is not specified, the directory will not exist. So log files will be in the default location
if ( Test-Path c:\temp ) {
    Write-Host("Setting TEMP & TMP environment variables to the VOLUME c:\temp")
    [Environment]::SetEnvironmentVariable("TMP", "c:\temp", "Process")
    [Environment]::SetEnvironmentVariable("TEMP", "c:\temp", "Process")
    # Require User to be set so that all install logs are redirected too
    [Environment]::SetEnvironmentVariable("TMP", "c:\temp", "User")
    [Environment]::SetEnvironmentVariable("TEMP", "c:\temp", "User")
}

# this is an alternative to using ServiceMonitor which would be added like this:
# Start-Process -NoNewWindow -FilePath C:\ServiceMonitor.exe -ArgumentList w3svc;
# The difference is that ServiceMonitor only promotes env vars into the w3svc process. Whereas
# the following code performs it for ALL processes. Hence items that might be wrtitten to c:\windows\temp should also
# be visible in the host's temp folder. And env vars set for x_run - for the web jobs - will be picked up by them too.

# copy process-level environment variables to machine level
foreach($key in [System.Environment]::GetEnvironmentVariables('Process').Keys) {
        $value = [System.Environment]::GetEnvironmentVariable($key, 'Process')
        [System.Environment]::SetEnvironmentVariable($key, $value, 'Machine')
}

& "$($ENV:GITREPOPATH)scripts\azure-custom-script.ps1" -server_name $server_name -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -MSIuri "$MSIuri";

& "C:\\bootstrap.ps1"