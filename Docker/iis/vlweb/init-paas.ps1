param(
    [String]$ApplName = 'Docker',
    [String]$server_name='xrobertpc\sqlserver2012',
    [String]$dbname='test1',
    [String]$dbuser,
    [String]$dbpassword,
    [String]$dbpasswordpath,    # Optional location of Docker Secret
    [String]$webuser,
    [String]$webpassword,
    [String]$webpasswordpath,   # Optional location of Docker Secret
    [Switch]$64bit,             # Need to default to 32 bit so change to a 64 bit switch flag
    [String]$SUDB = '1',
    [String]$maxconnections = '20',
    [String]$userscripthook,
    [Parameter(Mandatory=$false)]
    [String]$DBUT='MSSQLS',
    [String]$MSIuri,
    [String]$sshkeypath,        # Optional location of Docker Secret
    [String]$GitBranch='debug/paas',
    [String]$GitAppBranch='master',
    [String]$GitAppUrl,
    [String]$DebugFlag='N'
)

if ($DebugFlag -ne 'N' ) {
    $Dbug = $true
}
if ( $Dbug ) { Write-Host("Debugging")}

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
    Write-Host "Get latest build repo into Container"
    Get-ChildItem c:\
    Write-Host "GITREPOPATH: $ENV:GITREPOPATH";
    Set-Location $ENV:GITREPOPATH
    Get-ChildItem
    git pull

    # Copy ssh_config from where Dockerfile put it to the git dir
    # Did not put in Dockerfile becasuse could not work out how to escape the space in 'program files'. [] did not work. Backtick did not work.
    Copy-Item c:\ssh_config "$ENV:ProgramW6432\Git\etc\ssh\ssh_config"

    # Copy ssh key to location referred to by ssh_config
    # set the DB password
    $default_sshkeypath = "$ENV:TEMP\id_rsa"
    if ($sshkeypath -and (Test-Path $sshkeypath)) {
        Copy-Item $sshkeypath c:\id_rsa
        Write-Host "Using ssh key from secret file: $sshkeypath"
    }
    elseif (Test-Path $default_sshkeypath) {
        Copy-Item $default_sshkeypath c:\id_rsa
        Write-Host "Using ssh key from default file: $default_sshkeypath"
    }
    else {
        throw "No ssh key in $sshkeypath nor in $default_sshkeypath"
    }

    Write-Host "Update known_hosts with github.com details so that accessing remote repo does not prompt for permission"
    mkdir "$ENV:USERPROFILE\.ssh"
    ssh-keyscan github.com | set-content "$ENV:USERPROFILE\.ssh\known_hosts"

    Get-ChildItem c:\
    Write-Host "GITREPOPATH: $ENV:GITREPOPATH";
    Set-Location $ENV:GITREPOPATH
    Get-ChildItem
    git pull

    # set the DB password
    if ($dbpasswordpath -and (Test-Path $dbpasswordpath)) {
        $password = Get-Content -Raw $dbpasswordpath
        if ($password) {
            $dbpassword = $password
            Write-Host "Using database password from secret file: $dbpasswordpath"
        }
        else {
            Write-Host "WARNING: Using default database password, no password in secret file: $dbpasswordpath"
        }
    }
    else {
        Write-Host "WARNING: Using default database password, secret file not found at: $dbpasswordpath"
    }

    # set the web password
    if ($webpasswordpath -and (Test-Path $webpasswordpath)) {
        $password = Get-Content -Raw $webpasswordpath
        if ($password) {
            $webpassword = $password
            Write-Host "Using web password from secret file: $webpasswordpath"
        }
        else {
            Write-Host "WARNING: Using default web password, no password in secret file: $webpasswordpath"
        }
    }
    else {
        Write-Host "WARNING: Using default web password, secret file not found at: $webpasswordpath"
    }

    if (-not $MSIuri) {
        $MSIuri = "$ENV:TEMP\\lansa.msi"
    }
    Write-Host "Using MSI from $MSIuri"

    # Registry Symbolic Links do not work on Server Core, so explicitly specify them.
    # VL Runtime makes no use of 32-bit registry AFAIK.
    # Integrator and Web Server are entirely 64 bit.
    # Does 1200 use the 32-bit registry hive?
    # Should be OK.

    New-Item -Path HKLM:\Software\WOW6432Node  -Name 'LANSA' -Force
    New-ItemProperty -Path HKLM:\Software\WOW6432Node\LANSA  -Name 'GitBranch' -Value $GitBranch -PropertyType String -Force
    New-ItemProperty -Path HKLM:\Software\LANSA  -Name 'GitBranch' -Value $GitBranch -PropertyType String -Force

    # Last Exit Code to 0
    cmd /c exit 0 | Out-Default | Write-Host

    if (!$64bit) {
        $APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
    } else {
        $APPA = "${ENV:ProgramW6432}\$($ApplName)"
    }

    Write-Host "APPA = $APPA"

    Write-Host "Switch webserver.conf logging on"

    Add-Type -AssemblyName System.Web
    # First replace all the special characters
    $APPAEncoded = [System.Web.HttpUtility]::UrlEncode($APPA)
    # And then fix it: The ':' was mistakenly changed, so change it back '%3a' => ':'
    $APPAEncoded = $APPAEncoded -replace '%3a', ':'
    # then replace '+' with %20
    $APPAEncoded = $APPAEncoded -replace '\+', '%20'

    Write-Host "APPAEncoded = $APPAEncoded"

    $LogLevel = 'ERROR'
    if ( $Dbug ) {
         $LogLevel = 'DEBUG'
    }
    New-Item -Path "HKLM:\Software\LANSA\$($APPAEncoded)" -Name 'LANSAWEB' -Force
    New-ItemProperty -Path "HKLM:\Software\LANSA\$($APPAEncoded)\LANSAWEB"  -Name 'WEBCFG_LOG' -Value $LogLevel -PropertyType String -Force
    New-Item -Path "HKLM:\Software\WOW6432Node\LANSA\$($APPAEncoded)" -Name 'LANSAWEB' -Force
    New-ItemProperty -Path "HKLM:\Software\WOW6432Node\LANSA\$($APPAEncoded)\LANSAWEB"  -Name 'WEBCFG_LOG' -Value $LogLevel -PropertyType String -Force

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }

    Write-Host("ApplicationInstall")

    & "$($ENV:GITREPOPATH)scripts\install-lansa-msi.ps1" -dbname $dbName -userscripthook $userscripthook -ApplName $ApplName -MSIuri $MSIuri  -GitRepoUrl $GitAppUrl -GitRepoBranch $GitAppBranch `
    -server_name $server_name -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -dbut $DBUT -f32bit $(!$64bit) -HTTPPortNumber 80 -HTTPPortNumberHub 8101 -HostRoutePortNumber 4545 -JSMPortNumber 4561 -JSMAdminPortNumber 4581 -SUDB $SUDB -UPGD false

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }

    Write-Host("Update TPTH = %TEMP% and INST = NO in x_lansa.pro")
    Add-Content "$APPA\x_win95\x_lansa\x_lansa.pro" "`nTPTH=${ENV:TEMP}`nINST=NO`n"

    & "C:\\bootstrap.ps1"
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

