# When called from a Packer script, $env:TEMP was empty. Hence why I have the option to pass a temp location.
try {
    if ([string]::IsNullOrEmpty( $args[0]))
    {
       $tempFolder = $env:TEMP
    }
    else
    {
       $tempFolder = $args[0]
    }

    try {
        # AZCopy link now requires TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $AWSUrl = "https://aka.ms/downloadazcopy"
        $installer_file = (Join-Path $temppath 'AzCopy.msi')
        (New-Object System.Net.WebClient).DownloadFile($AWSUrl, $installer_file) | Out-Default | Write-Host
    } catch {
        throw "Failed to download $AWSUrl to $installer_file"
    }

    $InstallDir = "${ENV:ProgramFiles(x86)}\Azure"

    Run-ExitCode 'msiexec' @('/quiet', '/i', """$installer_file""", "AZURESTORAGETOOLSFOLDER=""$InstallDir""")

    Add-DirectoryToEnvPathOnce -Directory "$InstallDir\Azcopy"

    Write-Host "$(Log-Date) AzCopy installed"
} catch {
    Write-Host ($_ | format-list | out-string)
    Write-Host "$(Log-Date) AzCopy failed to install"
}