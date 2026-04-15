param(
    [String]$ApplName,
    [String]$server_name,
    [String]$dbname,
    [String]$dbuser,
    [SecureString]$dbpassword,
    [String]$dbpasswordpath,
    [String]$webuser,
    [SecureString]$webpassword,
    [String]$webpasswordpath,
    [String]$GitBranch,
    [Switch]$64bit,
    [String]$SUDB,
    [String]$maxconnections,
    [String]$userscripthook,
    [Parameter(Mandatory=$false)]
    [String]$DBUT,
    [String]$MSIuri,
    [Switch]$Dbug,
    [Parameter(Mandatory=$true)]
    [ValidateSet('AWS','Azure')]
    [String]$Cloud
)

Write-Host "Running within the container. Copies files from C:\docker\iis\AWAMAPP to C:\ and then invokes the base init.ps1 script with parameters forwarded from run.ps1"

$ErrorActionPreference = 'Stop'

$SourceDir = 'C:\docker\iis\AWAMAPP'
$IgnoreFile = Join-Path $SourceDir '.dockerignore'
$ContainerRoot = 'C:\'

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

$IgnorePatterns = @()
if (Test-Path -LiteralPath $IgnoreFile -PathType Leaf) {
    $IgnorePatterns = @(Get-Content -LiteralPath $IgnoreFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$Files = Get-ChildItem -LiteralPath $SourceDir -File | Sort-Object Name

foreach ($File in $Files) {
    if (Test-ShouldCopyFile -File $File -Patterns $IgnorePatterns) {
        $Destination = Join-Path $ContainerRoot $File.Name
        Write-Host("Copying $($File.Name) to $Destination")
        Copy-Item -LiteralPath $File.FullName -Destination $Destination -Force
    } else {
        Write-Host("Skipping $($File.Name) due to .dockerignore")
    }
}

$ForwardParams = @{
    server_name = $server_name
    dbname = $dbname
    dbuser = $dbuser
    dbpasswordpath = $dbpasswordpath
    webuser = $webuser
    webpasswordpath = $webpasswordpath
    MSIuri = $MSIuri
    Cloud = $Cloud
}

[string]::IsNullOrWhiteSpace($SQLHost)
if (-not [string]::IsNullOrWhiteSpace($ApplName)) {
    $ForwardParams.ApplName = $ApplName
}

if (-not [string]::IsNullOrWhiteSpace($dbpassword)) {
    $ForwardParams.dbpassword = $dbpassword
}

if (-not [string]::IsNullOrWhiteSpace($webpassword)) {
    $ForwardParams.webpassword = $webpassword
}

if (-not [string]::IsNullOrWhiteSpace($GitBranch)) {
    $ForwardParams.GitBranch = $GitBranch
}

if ($64bit) {
    $ForwardParams['64bit'] = $true
}

if (-not [string]::IsNullOrWhiteSpace($SUDB)) {
    $ForwardParams.SUDB = $SUDB
}

if (-not [string]::IsNullOrWhiteSpace($maxconnections)) {
    $ForwardParams.maxconnections = $maxconnections
}

if (-not [string]::IsNullOrWhiteSpace($userscripthook)) {
    $ForwardParams.userscripthook = $userscripthook
}

if (-not [string]::IsNullOrWhiteSpace($DBUT)) {
    $ForwardParams.DBUT = $DBUT
}

if ($Dbug) {
    $ForwardParams.Dbug = $true
}

$LicenseRegistryPaths = @(
    'HKLM:\SOFTWARE\LANSA\COMMON'
    'HKLM:\SOFTWARE\WOW6432Node\LANSA\COMMON'
)

foreach ($LicenseRegistryPath in $LicenseRegistryPaths) {
    Write-Host("Registry: $LicenseRegistryPath")
    New-Item -Path $LicenseRegistryPath -Force | Out-Null
    Write-Host("Registry: $LicenseRegistryPath [LicenseDir] = C:\")
    Set-ItemProperty -Path $LicenseRegistryPath -Name 'LicenseDir' -Value 'C:\' -Type String
}

& 'C:\init.ps1' @ForwardParams
