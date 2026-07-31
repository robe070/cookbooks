param(
    [String]$ApplName = 'Docker',
    [String]$server_name,
    [String]$dbname='test1',
    [String]$dbuser,
    [SecureString]$dbpassword,
    [String]$dbpasswordpath,    # Optional location of Docker Secret
    [String]$webuser,
    [SecureString]$webpassword,
    [String]$webpasswordpath,   # Optional location of Docker Secret
    [String]$GitBranch='debug/paas',
    [Switch]$64bit,             # Need to default to 32 bit so change to a 64 bit switch flag
    [String]$SUDB = '1',
    [String]$maxconnections = '20',
    [String]$userscripthook,
    [Parameter(Mandatory=$false)]
    [String]$DBUT='MSSQLS',
    [String]$MSIuri,
    [Switch]$Dbug,
    [Parameter(Mandatory=$true)]
    [ValidateSet('AWS','Azure')]
    [String]$Cloud
)

if ( $Dbug ) { Write-Host("Debugging")}

function Write-RegAssignment {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host ("Registry: {0}" -f $Path)
    } else {
        Write-Host ("Registry: {0} [{1}] = {2}" -f $Path, $Name, $Value)
    }
}

function Test-MatchesPattern {
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $FileName,

        [Parameter(Mandatory=$true)]
        [string]
        $RelativePath,

        [Parameter(Mandatory=$true)]
        [string]
        $Pattern
    )

    $NormalizedPattern = $Pattern.Trim().Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($NormalizedPattern)) {
        return $false
    }

    if ($NormalizedPattern.StartsWith('/')) {
        $NormalizedPattern = $NormalizedPattern.Substring(1)
    }

    if ($NormalizedPattern.EndsWith('/')) {
        return $false
    }

    $NormalizedRelativePath = $RelativePath.Replace('\', '/')
    return $FileName -like $NormalizedPattern -or $NormalizedRelativePath -like $NormalizedPattern
}

function Test-ShouldCopyFile {
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]
        $File,

        [Parameter(Mandatory=$true)]
        [string[]]
        $Patterns
    )

    if ($File.Name -eq '.dockerignore') {
        return $false
    }

    if ($File.Name -notlike '*.*') {
        return $false
    }

    $RelativePath = $File.Name
    $IsIgnored = $false

    foreach ($RawPattern in $Patterns) {
        $Pattern = $RawPattern.Trim()
        if ([string]::IsNullOrWhiteSpace($Pattern) -or $Pattern.StartsWith('#')) {
            continue
        }

        $IsNegated = $Pattern.StartsWith('!')
        if ($IsNegated) {
            $Pattern = $Pattern.Substring(1).Trim()
        }

        if ([string]::IsNullOrWhiteSpace($Pattern)) {
            continue
        }

        if (Test-MatchesPattern -FileName $File.Name -RelativePath $RelativePath -Pattern $Pattern) {
            $IsIgnored = -not $IsNegated
        }
    }

    return -not $IsIgnored
}

# Copy the AWAMAPP payload from the mounted repo into C:\ before running the install.
$SourceDir = 'C:\docker\iis\AWAMAPP'
$IgnoreFile = Join-Path $SourceDir '.dockerignore'
$ContainerRoot = 'C:\'

if (Test-Path -LiteralPath $SourceDir -PathType Container) {
    $IgnorePatterns = @()
    if (Test-Path -LiteralPath $IgnoreFile -PathType Leaf) {
        $IgnorePatterns = @(Get-Content -LiteralPath $IgnoreFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $Files = Get-ChildItem -LiteralPath $SourceDir -File | Sort-Object Name
    foreach ($File in $Files) {
        if (Test-ShouldCopyFile -File $File -Patterns $IgnorePatterns) {
            $Destination = Join-Path $ContainerRoot $File.Name
            if ($Destination -ieq $PSCommandPath) {
                continue
            }

            Write-Host("Copying $($File.Name) to $Destination")
            Copy-Item -LiteralPath $File.FullName -Destination $Destination -Force
        } else {
            Write-Host("Skipping $($File.Name) due to .dockerignore")
        }
    }
}

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
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    "Container Windows Version {0} {1}.{2}" -f $cv.DisplayVersion, $cv.CurrentBuild, $cv.UBR

    git config --global --add safe.directory $ENV:GITREPOPATH  | Out-Default | Write-Host

    Write-Host "Get latest build repo into Container"
    Get-ChildItem c:\
    Write-Host "GITREPOPATH: $ENV:GITREPOPATH";
    Set-Location $ENV:GITREPOPATH
    Get-ChildItem
    git pull

    Write-Host("Testing connectivity to SQL Server at $server_name...")
    $DNSName = $server_name.Split(',')[0].Replace('tcp:','')
    $Port = $server_name.Split(',')[1]
    $isIp = [System.Net.IPAddress]::TryParse($DNSName, [ref]$null)
    if (-not $isIp) {
        Write-Host("Resolving DNS for $DNSName...")
        $result = Resolve-DnsName $DNSName -ErrorAction Stop
        if (-not $result) {
            throw "DNS resolution returned no results for $DNSName."
        }
    }

    Write-Host("Testing connectivity to SQL Server at $DNSName on port $Port...")
    $result = Test-NetConnection $DNSName -Port $Port -ErrorAction Stop
    if (-not $result.TcpTestSucceeded) {
        throw "SQL connectivity test failed. Host=$DNSName Port=$Port PingSucceeded=$($result.PingSucceeded) TcpTestSucceeded=$($result.TcpTestSucceeded)"
    }

    # set the DB password
    if ($dbpasswordpath -and (Test-Path $dbpasswordpath)) {
        $password = Get-Content -Raw $dbpasswordpath
        $password
        if ($password) {
            $dbpassword = ConvertTo-SecureString -String $password -AsPlainText -Force
            $dbpassword
            Write-Host "Using database password from secret file: $dbpasswordpath"
        } else {
            Write-Host "WARNING: Using default database password, no password in secret file: $dbpasswordpath"
        }
    }

    if ( -not $dbpassword) {
        throw "-dbpassword not set"
    }

    # set the web password
    if ($webpasswordpath -and (Test-Path $webpasswordpath)) {
        $password = Get-Content -Raw $webpasswordpath
        if ($password) {
            $webpassword = ConvertTo-SecureString -String $password -AsPlainText -Force
            Write-Host "Using web password from secret file: $webpasswordpath"
        } else {
            Write-Host "WARNING: Using default web password, no password in secret file: $webpasswordpath"
        }
    }
    else {
        Write-Host "WARNING: Using default web password, secret file not found at: $webpasswordpath"
    }

    if ( -not $webpassword) {
        throw "-webpassword not set"
    }

    if (-not $MSIuri) {
        Write-Host "Pull down the default docker msi image from AWS S3 based on the git branch being used"
        switch ($GitBranch) {
            'debug/paas' { $MSIuri = 'https://lansa-us-east-1.s3.amazonaws.com/app/paas-debug/DOCKER_v1.0.0_en-us.msi' }
            'patch/paas' { $MSIuri = 'https://lansa-us-east-1.s3.amazonaws.com/app/paas-test/DOCKER_v1.0.0_en-us.msi' }
            Default { $MSIuri = 'https://lansa-us-east-1.s3.amazonaws.com/app/paas-live/DOCKER_v1.0.0_en-us.msi' }
        }
    }
    Write-Host "Using MSI from $MSIuri"

    # Registry Symbolic Links do not work on Server Core, so explicitly specify them.
    # VL Runtime makes no use of 32-bit registry AFAIK, because there is no registry use.
    # Integrator and Web Server are entirely 64 bit.
    # Does 1200 use the 32-bit registry hive?

    # New-Item -Path HKLM:\Software\WOW6432Node  -Name 'LANSA' -Force
    # New-ItemProperty -Path HKLM:\Software\WOW6432Node\LANSA  -Name 'GitBranch' -Value $GitBranch -PropertyType String -Force
    # New-ItemProperty -Path HKLM:\Software\LANSA  -Name 'GitBranch' -Value $GitBranch -PropertyType String -Force

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
    Write-RegAssignment -Path "HKLM:\Software\LANSA\$($APPAEncoded)\LANSAWEB"
    New-Item -Path "HKLM:\Software\LANSA\$($APPAEncoded)" -Name 'LANSAWEB' -Force
    Write-RegAssignment -Path "HKLM:\Software\LANSA\$($APPAEncoded)\LANSAWEB" -Name 'WEBCFG_LOG' -Value $LogLevel
    New-ItemProperty -Path "HKLM:\Software\LANSA\$($APPAEncoded)\LANSAWEB"  -Name 'WEBCFG_LOG' -Value $LogLevel -PropertyType String -Force
    Write-RegAssignment -Path "HKLM:\Software\WOW6432Node\LANSA\$($APPAEncoded)\LANSAWEB"
    New-Item -Path "HKLM:\Software\WOW6432Node\LANSA\$($APPAEncoded)" -Name 'LANSAWEB' -Force
    Write-RegAssignment -Path "HKLM:\Software\WOW6432Node\LANSA\$($APPAEncoded)\LANSAWEB" -Name 'WEBCFG_LOG' -Value $LogLevel
    New-ItemProperty -Path "HKLM:\Software\WOW6432Node\LANSA\$($APPAEncoded)\LANSAWEB"  -Name 'WEBCFG_LOG' -Value $LogLevel -PropertyType String -Force

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }

    Write-Host("Licensing Install...")
    # Create license directory
    $LicenseDir = 'C:\'
    # New-Item -ItemType Directory -Path $LicenseDir -Force | Out-Null

    # Create registry key and set LicenseDir
    Write-RegAssignment -Path 'HKLM:\SOFTWARE\LANSA\COMMON'
    New-Item -Path 'HKLM:\SOFTWARE\LANSA\COMMON' -Force | Out-Null
    Write-RegAssignment -Path 'HKLM:\SOFTWARE\WOW6432Node\LANSA\COMMON'
    New-Item -Path 'HKLM:\SOFTWARE\WOW6432Node\LANSA\COMMON' -Force | Out-Null
    Write-RegAssignment -Path 'HKLM:\SOFTWARE\LANSA\COMMON' -Name 'LicenseDir' -Value $LicenseDir
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\LANSA\COMMON' -Name 'LicenseDir' -Value $LicenseDir
    Write-RegAssignment -Path 'HKLM:\SOFTWARE\WOW6432Node\LANSA\COMMON' -Name 'LicenseDir' -Value $LicenseDir
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\LANSA\COMMON' -Name 'LicenseDir' -Value $LicenseDir
    Write-RegAssignment -Path 'HKLM:\SOFTWARE\LANSA' -Name 'Cloud' -Value $Cloud
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\LANSA' -Name 'Cloud' -Value $Cloud
    Write-RegAssignment -Path 'HKLM:\SOFTWARE\WOW6432Node\LANSA' -Name 'Cloud' -Value $Cloud
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\LANSA' -Name 'Cloud' -Value $Cloud
        
    Write-Host("ApplicationInstall")

    & "$($ENV:GITREPOPATH)\scripts\install-lansa-msi.ps1" -dbname $dbName -userscripthook $userscripthook -ApplName $ApplName -MSIuri $MSIuri `
        -server_name $server_name `
        -dbuser $dbuser -dbpassword ([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbpassword))) `
        -webuser $webuser -webpassword ([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($webpassword))) -dbut $DBUT -f32bit $(!$64bit) `
        -HTTPPortNumber 80 -HTTPPortNumberHub 8101 -HostRoutePortNumber 4545 -JSMPortNumber 4561 -JSMAdminPortNumber 4581 -SUDB $SUDB -UPGD false

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }

    Write-Host("Update TPTH = $($env:temp) and INST = NO in x_lansa.pro")
    Add-Content "$APPA\x_win95\x_lansa\x_lansa.pro" "`nTPTH=${ENV:TEMP}`nINST=NO`n"

    & "C:\\bootstrap.ps1" -ByPassSQLServerDNSChecks
} catch {
    $_

    # Exit here on error if NOT debugging. Else Sleep so container may be investigated for debugging purposes
    # if ( $Dbug ) {
    #     while ($true) {
    #         Write-Host "Sleeping..."
    #         Start-Sleep -Seconds 3600
    #     }
    # } else {
    #     if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    #         throw
    #     }
    # }

    throw
}
