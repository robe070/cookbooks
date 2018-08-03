<#
.SYNOPSIS

Modify CloudWatch logging configuration for the Region and Stack

.EXAMPLE


#>
param(
[Parameter(Mandatory=$true)]
[String]$Stack,
[String]$Region,
[String]$f32bit = 'true'
)

# Put first output on a new line in cfn_init log file
Write-Host ("`r`n")

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

# $DebugPreference = "Continue"
# $VerbosePreference = "Continue"

Write-Debug ("Stack = $Stack") | Out-Host
Write-Debug ("Region = $Region") | Out-Host
Write-Debug ("32bit = $f32bit") | Out-Host

try
{
    # Write-Warning ("Disable logging configuration whilst working out how to use CloudWatch Agent")
    # cmd /c exit 0
    # return

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    Write-Host ("$(Log-Date) Running on $Cloud")

    if ( ($Cloud -eq "AWS") ) {
        $CWADirectory = 'Amazon\AmazonCloudWatchAgent'
        $CWAProgramFiles = "${Env:ProgramFiles}\${CWADirectory}"
        if ($Env:ProgramData) {
            $CWAProgramData = "${Env:ProgramData}\${CWADirectory}"
        } else {
            # Windows 2003
            $CWAProgramData = "${Env:ALLUSERSPROFILE}\Application Data\${CWADirectory}"
        }

        Write-Host ("$(Log-Date) Stopping CloudWatch Agent, if its installed")

        $CWAController = Join-Path $CWAProgramFiles -ChildPath 'amazon-cloudwatch-agent-ctl.ps1'
        if ( Test-Path $CWAController ) {
            & $CWAController -a stop | Out-Host
        }

        Write-Warning("$(Log-Date) Installation of CloudWatch Agent needs to be moved to Baking of the AMI") | Out-Host

        $CWASetup = 'https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/AmazonCloudWatchAgent.zip'
        $installer_file = ( Join-Path -Path $env:temp -ChildPath 'AmazonCloudWatchAgent.zip' )
        Write-Host ("$(Log-Date) Downloading $CWASetup to $installer_file")
        $downloaded = $false
        $TotalFailedDownloadAttempts = 0
        $TotalFailedDownloadAttempts = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'TotalFailedDownloadAttempts' -ErrorAction SilentlyContinue).TotalFailedDownloadAttempts
        $loops = 0
        while (-not $Downloaded -and ($Loops -le 10) ) {
            try {
                (New-Object System.Net.WebClient).DownloadFile($CWASetup, $installer_file) | Out-Host
                $downloaded = $true
            } catch {
                $TotalFailedDownloadAttempts += 1
                New-ItemProperty -Path HKLM:\Software\LANSA  -Name 'TotalFailedDownloadAttempts' -Value ($TotalFailedDownloadAttempts) -PropertyType DWORD -Force | Out-Null                  
                $loops += 1

                Write-Host ("$(Log-Date) Total Failed Download Attempts = $TotalFailedDownloadAttempts")

                if ($loops -gt 10) {
                    throw "Failed to download $CWASetup from S3"
                }

                # Pause for 30 seconds. Maybe that will help it work?
                Start-Sleep 30
            }
        }
    
        $InstallerDirectory = ( Join-Path -Path $env:temp -ChildPath 'AmazonCloudWatchAgent' )
        Expand-Archive $installer_file -DestinationPath $InstallerDirectory -Force | Out-Host

        # Installer file MUST be executed with the current directory set to the installer directory
        $InstallerScript = '.\install.ps1'
        Set-Location $InstallerDirectory
        & $InstallerScript | Out-Host

        $CWASrcConfig = Join-Path -Path $script:IncludeDir -ChildPath '..\CloudFormationWindows\CWA.json'
        $CWAConfig = Join-Path -Path $CWAProgramData -ChildPath 'CWA.json'

        copy-item -Path $CWASrcConfig -Destination $CWAConfig -Force

        Write-Host ("Updating $CWAConfig")

        # Use backtick to escape double quotes
        (Get-Content $CWAConfig) |
        Foreach-Object {$_ -replace "{stack_id}","$Stack"}  | Set-Content ($CWAConfig)

        & $CWAController -a fetch-config -m ec2 -c file:$CWAConfig -s | Out-Host
    }
}
catch
{
    $_

    cmd /c exit 2
    throw "Log configuration failed"
}

Write-Host ("Log configuration successful")
cmd /c exit 0
