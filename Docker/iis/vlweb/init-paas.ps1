param(
    [String]$server_name='xrobertpc\sqlserver2012',
    [String]$dbname='test1',
    [String]$dbuser = 'admin',
    [String]$dbpassword = 'password',
    [String]$webuser = 'PCXUSER2',
    [String]$webpassword = 'PCXUSER@122',
    [String]$f32bit='true',
    [String]$SUDB = '1',
    [String]$maxconnections = '20',
    [String]$userscripthook,
    [Parameter(Mandatory=$false)]
    [String]$DBUT='MSSQLS',
    [String]$MSIuri,
    [String]$GitBranch='debug/paas',
    [String]$GitBranchWebserver='debug/paas',
    [Switch]$Dbug
)

if ( $Dbug ) { Write-Host("Debugging")}

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
# the following code performs it for ALL processes. Hence items that might be written to c:\windows\temp should also
# be visible in the host's temp folder. And env vars set for x_run - for the web jobs - will be picked up by them too.

# copy process-level environment variables to machine level
foreach($key in [System.Environment]::GetEnvironmentVariables('Process').Keys) {
        $value = [System.Environment]::GetEnvironmentVariable($key, 'Process')
        [System.Environment]::SetEnvironmentVariable($key, $value, 'Machine')
}
try {
    if ( $f32bit -eq 'true' -or $f32bit -eq '1')
    {
        $f32bit_bool = $true
    }
    else
    {
        $f32bit_bool = $false
    }

    # Registry Symbolic Links do not work on Server Core, so explicitly specify them.
    # VL Runtime makes no use of 32-bit regisatry AFAIK.
    # Integrator and Web Server are entirely 64 bit.
    # Does 1200 use teh 32-bit registry hive?
    # Should be OK.
    New-Item -Path HKLM:\Software\WOW6432Node  -Name 'LANSA' -Force
    New-ItemProperty -Path HKLM:\Software\WOW6432Node\LANSA  -Name 'GitBranch' -Value $GitBranch -PropertyType String -Force
    New-ItemProperty -Path HKLM:\Software\WOW6432Node\LANSA  -Name 'GitBranchWebServr' -Value $GitBranchWebServer -PropertyType String -Force
    New-ItemProperty -Path HKLM:\Software\LANSA  -Name 'GitBranch' -Value $GitBranch -PropertyType String -Force
    New-ItemProperty -Path HKLM:\Software\LANSA  -Name 'GitBranchWebServr' -Value $GitBranchWebServer -PropertyType String -Force

    # $CommonParams = -server_name $server_name -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -dbut $DBUT -f32bit 1 -HTTPPortNumber 80 -HTTPPortNumberHub 8101 -HostRoutePortNumber 4540 -JSMPortNumber 4561 -JSMAdminPortNumber 4581 -SUDB $SUDB -UPGD false

    Write-Host("Webserver Install...")
    & "$($ENV:GITREPOPATH)scripts\install-lansa-msi.ps1" -MSIUri https://s3.amazonaws.com/lansa-us-east-1/app/paas-live/WEBSERVR_v1.0.0_en-us.msi -ApplName WebServer  -dbname webserver -gitrepourl https://github.com/lansa/webserver.git  `
    -server_name $server_name -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -dbut $DBUT -f32bit $f32bit_bool -HTTPPortNumber 80 -HTTPPortNumberHub 8101 -HostRoutePortNumber 4540 -JSMPortNumber 4561 -JSMAdminPortNumber 4581 -SUDB $SUDB -UPGD false

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }

    # Last Exit Code to 0
    cmd /c exit 0 | Out-Default | Write-Host

    Write-Host("ApplicationInstall")
    $ApplName = "WebServer"
    if ($f32bit_bool) {
        $APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
    } else {
        $APPA = "${ENV:ProgramFiles}\$($ApplName)"
    }

    $ApplicationName = 'APP1'
    $GitRepoName = "lansaeval301"
    $ApplMSIuri = "https://s3.amazonaws.com/lansa-us-east-1/app/paas-live"
    & "$($ENV:GITREPOPATH)scripts\install-lansa-msi.ps1" -dbname $ApplicationName -userscripthook $userscripthook -ApplName $ApplicationName -CompanionInstallPath $APPA -MSIuri "$ApplMSIuri/$($ApplicationName)_v1.0.0_en-us.msi"  -GitRepoUrl "git@github.com:lansa/$($GitRepoName).git" `
    -server_name $server_name -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -dbut $DBUT -f32bit $f32bit_bool -HTTPPortNumber 80 -HTTPPortNumberHub 8101 -HostRoutePortNumber 4540 -JSMPortNumber 4561 -JSMAdminPortNumber 4581 -SUDB $SUDB -UPGD false

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }
} catch {
    $_

    # Exit here on error if NOT debugging. Else Sleep so container may be investigated for debugging purposes
    if ( $Dbug ) {
        while ($true) {
            Write-Host "Sleeping..."
            Start-Sleep -Seconds 3600
        }
    } else {
        if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            throw
        }
    }
}
& "C:\\bootstrap.ps1"
