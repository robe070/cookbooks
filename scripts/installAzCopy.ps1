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

    $source = "http://aka.ms/downloadazcopy"
    $destination = Join-Path -Path $tempFolder -ChildPath "AzCopy.msi"
    $InstallDir = "${ENV:ProgramFiles(x86)}\Azure"
    $wc = New-Object system.net.webclient
    $wc.downloadFile( $source, $destination ) | Write-Output

    Run-ExitCode 'msiexec' @('/quiet', '/i', """$destination""", "AZURESTORAGETOOLSFOLDER=""$InstallDir""")

    Add-DirectoryToEnvPathOnce -Directory "$InstallDir\Azcopy"

    Write-Output "$(Log-Date) AzCopy installed"
} catch {
    Write-Error ($_ | format-list | out-string)
    Write-Output "$(Log-Date) AzCopy failed to install"
}