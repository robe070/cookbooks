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

Write-Debug ("Stack = $Stack") | Write-Host
Write-Debug ("Region = $Region") | Write-Host
Write-Debug ("32bit = $f32bit") | Write-Host

try
{
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

        # Write-Host ("$(Log-Date) Stopping CloudWatch Agent, if its installed")

        $CWAController = Join-Path $CWAProgramFiles -ChildPath 'amazon-cloudwatch-agent-ctl.ps1'
        # if ( Test-Path $CWAController ) {
        #     & $CWAController -a stop | Write-Host
        # }

        Write-Host ("$(Log-Date) Configuring CloudWatch Agent")

        $CWASrcConfig = Join-Path -Path $script:IncludeDir -ChildPath '..\CloudFormationWindows\CWA.json'
        $CWAConfig = Join-Path -Path $CWAProgramData -ChildPath 'CWA.json'

        copy-item -Path $CWASrcConfig -Destination $CWAConfig -Force

        # Use backtick to escape double quotes

        Write-Host( "$(Log-Date) Replace LANSA-specific replacement variables")

        (Get-Content $CWAConfig) | Foreach-Object {$_ -replace "{stack_id}","$Stack"}  | Set-Content ($CWAConfig)

        Write-Host( "$(Log-Date) Apply new configuration file $CWAConfig, but DO NOT START IT. Use Systems Manager when you need to troubleshoot")

        & $CWAController -a fetch-config -m ec2 -c file:$CWAConfig | Write-Host
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
