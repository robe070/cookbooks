<#
.SYNOPSIS

UnInstall a LANSA MSI.

.EXAMPLE

#>

param(
    [String]$server_name,
    [String]$dbname,
    [String]$dbuser,
    [String]$dbpassword,    
    [String]$f32bit = 'true',
    [String]$SUDB = '1',
    [String]$DBUT='MSSQLS',
    [String]$trace = 'N',
    [String]$traceSettings = "ITRO:Y ITRL:4 ITRM:9999999999",
    [String]$ApplName = "MyApp",
    [String]$CompanionInstallPath = ""
)

function Log-Date 
{
    ((get-date)).ToString("yyyy-MM-dd HH:mm:ss")
}

# Load functions in other source files
$ScriptPath = (Split-Path $MyInvocation.MyCommand.Path)
. "$($ScriptPath)\dot-DBTools.ps1"

# Put first output on a new line in log file
Write-Output ("`r`n")

$DebugPreference = "SilentlyContinue"
$VerbosePreference = "Continue"

$installer = "$($ApplName).msi"

$installer_file = ( Join-Path -Path "c:\lansa" -ChildPath $installer )
$install_log = ( Join-Path -Path $ENV:TEMP -ChildPath "$($ApplName)_uninstall.log" )

Write-Verbose ("installer_file = $installer_file")

try {
    $ExitCode = 0

    $temp_out = ( Join-Path -Path $ENV:TEMP -ChildPath temp_install.log )
    $temp_err = ( Join-Path -Path $ENV:TEMP -ChildPath temp_install_err.log )

    # Write-Output ("$(Log-Date) Setup tracing for both this process and its children and any processes started after the installation has completed.")

    # if ($trace -eq "Y") {
    #     [Environment]::SetEnvironmentVariable("X_RUN", $traceSettings, "Machine")
    #     $env:X_RUN = $traceSettings
    # } else {
    #     [Environment]::SetEnvironmentVariable("X_RUN", $null, "Machine")
    #     $env:X_RUN = ''
    # }

    Write-Output ("$(Log-Date) Uninstalling the application")

    [String[]] $Arguments = @( "/quiet /lv*x ""$install_log"" /x ""$installer_file""")

    Write-Output ("$(Log-Date) Arguments = $Arguments")

    $x_err = (Join-Path -Path $ENV:TEMP -ChildPath 'x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue

    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $Arguments -Wait -PassThru

    if ( $p.ExitCode -ne 0 ) {
        $ExitCode = $p.ExitCode
        $ErrorMessage = "MSI Install returned error code $($p.ExitCode)."
        Write-Error $ErrorMessage -Category NotInstalled
        throw $ErrorMessage
    }

    if ( ($SUDB -eq '1') {
        switch ($DBUT) {
            "MSSQLS" {
                Write-Output ("$(Log-Date) Drop Database...")

                Write-Output ("$(Log-Date) Ensure SQL Server Powershell module is loaded.")

                Write-Verbose ("$(Log-Date) Loading this module changes the current directory to 'SQLSERVER:\'. It will need to be changed back later")

                # Note that warnings are displayed which may be ignored.
                $VerbosePreferenceSaved = $VerbosePreference
                $VerbosePreference = "SilentlyContinue"
                Import-Module "sqlps" -DisableNameChecking
                $VerbosePreference = $VerbosePreferenceSaved

                Drop-SqlServerDatabase $server_name $dbname $dbuser $dbpassword

                Write-Verbose ("$(Log-Date) Change current directory from 'SQLSERVER:\' back to the file system so that file pathing works properly")
                cd "c:"
            }
            default {
                $ErrorMessage = "$(Log-Date) $DBUT Database not currently supported"
                $ExitCode = 5
                Write-Error $ErrorMessage -Category NotInstalled
                throw $ErrorMessage                
            }
        }
    }
    
	Write-Output ("$(Log-Date) Uninstallation completed successfully")
} catch {
	$_
    Write-Output ("$(Log-Date) Uninstallation error ExitCode=$ExitCode; LastExitCode=$LASTEXITCODE")
    if ( $ExitCode -eq 0 -and $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        $ExitCode = $LASTEXITCODE
    }
    if ($ExitCode -eq 0 -or -not $ExitCode) {$ExitCode = 1}

    Write-Output ("$(Log-Date) State Before returning: ExitCode=$ExitCode")
    Write-Output ("$(Log-Date) An exit code of 1605 means the MSI is not installed")
    Write-Output ("$(Log-Date) An exit code of 1603 is an installer error so look at $install_log")
    Write-Output ("$(Log-Date) An exit code of 1602 means the application is already installed using a different build of the MSI. See the powershell.log file")
    Write-Output ("$(Log-Date) An exit code of 1 is a command line error when executing the powershell script. See the main log file")

    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    return
}
finally
{
    Write-Output ("$(Log-Date) See $install_log and other files in $ENV:TEMP for more details.")
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
