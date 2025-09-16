<#
.SYNOPSIS

Example user script executed at end of LANSA MSI Install

The same parameters are passed to this script as are passed to the caller, install-lansa-msi.ps1

Git Test 2
.EXAMPLE


#>
param(
[String]$server_name='robertpc\sqlserver2012',
[String]$dbname='test1',
[String]$dbuser = 'admin',
[String]$dbpassword = 'password',
[String]$webuser = 'PCXUSER2',
[String]$webpassword = 'PCXUSER@122',
[String]$f32bit = 'true',
[String]$SUDB = '1',
[String]$UPGD = 'false',
[String]$userscripthook
)
try
{
    $DebugPreference = "Continue"
    $VerbosePreference = "Continue"
    Write-Verbose ("Previous 2 lines display Debug and Verbose messages")

    Write-Verbose ("Use Write-Verbose instead of comments. Then they can be useful in the log, and not just to the programmer writing the script")

    Write-Verbose ("Use Write-Host for messages that should always be displayed. E.g. Major steps in the process")
    Write-Output ( "User Script started")

    Write-Output ("Executing $userscripthook")

    Write-Verbose ("Use Write-Debug for debug messages, duh!")
    Write-Debug ("Server_name = $server_name")
    Write-Debug ("dbname = $dbname")
    Write-Debug ("dbuser = $dbuser")
    Write-Debug ("webuser = $webuser")
    Write-Debug ("32bit = $f32bit")
    Write-Debug ("SUDB = $SUDB")
    Write-Debug ("UPGD = $UPGD")

    # This script sets the Production value under HKEY_LOCAL_MACHINE\Software\LANSA to True (REG_DWORD, value 1).
    # The effect is to firstly enforce Marketplace Product Code Validation. This ensures that stacks created
    # in the LANSA LPC Cloud Accounts behave in the same way as stacks created in customer accounts.
    # Secondly, it stops default development licenses being created, speeding up startup time.
    # Assumptions:
    # - Runs in Azure DevOps self-hosted Windows agent context.
    # - Compatible with PowerShell 5.1.
    # - Requires administrative privileges to write to HKLM.

    try {
        $registryPath = "HKLM:\Software\LANSA"
        $valueName = "Production"
        $valueData = 1  # Boolean True as REG_DWORD

        # Check if the registry key exists, create it if it doesn't
        if (-not (Test-Path -Path $registryPath)) {
            throw "Registry key $registryPath not found."
        } else {
            Write-Host "Registry key $registryPath found."
        }

        # Set the Production value to True (1)
        Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type DWord -Force
        Write-Host "Production value set to True (1)."

        # Verify the value was set
        $setValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction Stop
        if ($setValue.$valueName -eq $valueData) {
            Write-Host "Production value verified as True (1)."
        } else {
            Write-Error "Failed to verify Production value. Expected: $valueData, Found: $($setValue.$valueName)"
        }
    } catch {
        Write-Error "Error setting registry value: $_"
        throw
    }

    Write-Output ( "User Script completed successfully")
}
catch
{
    Write-Error ( "User Script failed")
    throw
}
