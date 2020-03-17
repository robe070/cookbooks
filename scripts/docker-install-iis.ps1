# presumes that these directories exist:
# c:\temp mapped to host temporary directory
# c:\scripts to host  Cookbooks\scripts
# c:\lansa container directory for the msi location

try {
    Push-Location

    [Environment]::SetEnvironmentVariable("TMP", "c:\temp", "Process")
    [Environment]::SetEnvironmentVariable("TEMP", "c:\temp", "Process")

    # # If environment not yet set up, it should be running locally, not through Remote PS
    # if ( -not $script:IncludeDir)
    # {
    #     # Log-Date can't be used yet as Framework has not been loaded

    #     Write-Host "Initialising environment - presumed not running through RemotePS"
    #     $MyInvocation.MyCommand.Path
    #     $script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    #     . "$script:IncludeDir\Init-Baking-Vars.ps1"
    #     . "$script:IncludeDir\Init-Baking-Includes.ps1"
    # }
    # else
    # {
    #     Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
    # }



    Write-Host "Adding features to IIS"
    Enable-WindowsOptionalFeature -online -FeatureName NetFx4Extended-ASPNET45
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45

    # Write-Output "Enabling Remote IIS Management"
    # install-windowsfeature web-mgmt-service
    # Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
    # Set-Service -name WMSVC -StartupType Automatic
    # Start-service WMSVC

    Write-Host "Set LANSA Cloud registry entries"
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
    Write-Host ("Finished")
}
