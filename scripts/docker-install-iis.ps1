# presumes that these directories exist:
# c:\temp mapped to host temporary directory
# c:\scripts to host  Cookbooks\scripts
# c:\lansa container directory for the msi location

try {
    Push-Location

    [Environment]::SetEnvironmentVariable("TMP", "c:\temp", "Process")
    [Environment]::SetEnvironmentVariable("TEMP", "c:\temp", "Process")

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



    # Write-Output "Installing IIS"
    # import-module servermanager
    # install-windowsfeature web-server

    # Write-Output "Enabling Remote IIS Management"
    # install-windowsfeature web-mgmt-service
    # Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
    # Set-Service -name WMSVC -StartupType Automatic
    # Start-service WMSVC

    Write-Output "Turning off complex password requirements"
    secedit /export /cfg c:\secpol.cfg
    return
    (Get-Content C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
    Remove-Item -force c:\secpol.cfg -confirm:$false

    Write-Output "Create local user test (pwd=test)"
    NET USER test "test" /ADD
    NET LOCALGROUP "Administrators" "test" /ADD

    Write-Output "Set LANSA Cloud registry entries"
    $lansaKey = 'HKLM:\Software\LANSA\'
    if (!(Test-Path -Path $lansaKey)) {
       New-Item -Path $lansaKey
    }
    New-ItemProperty -Path $lansaKey  -Name 'Cloud' -PropertyType String -Value 'Docker' -Force

    # add-odbcdsn -name trunk -DriverName "ODBC Driver 13 for SQL Server" -setPropertyValue @("Server=robgw10","Trusted_Connection=No", "Database=Trunk") -Platform "32-bit" -DsnType "System"

} catch {
    $_ | Out-default | Write-Host
    Write-Error ("Failed")
} finally {
    Pop-Location
    Write-Output ("Finished")
}
