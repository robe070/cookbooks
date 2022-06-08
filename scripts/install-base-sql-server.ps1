<#
.SYNOPSIS

Install miscellaenous stuff. Only vaguely related to SQL Server now.
Required because this cannot be executed remotely. It must be executed directly on the machine
   C:\Windows\system32\dism.exe /online /enable-feature /featurename:IIS-NetFxExtensibility /norestart  /All


.EXAMPLE


#>

. "c:\lansa\scripts\dot-CommonTools.ps1"

$OutputFile = "$ENV:TEMP\output1.txt"
$ErrorFile = "$ENV:TEMP\error1.txt"
$ResultFile = "$ENV:TEMP\resultcode1.txt"
Remove-Item -Path $OutputFile -ErrorAction SilentlyContinue
Remove-Item -Path $ErrorFile -ErrorAction SilentlyContinue
Remove-Item -Path $ResultFile -ErrorAction SilentlyContinue

if ( -not $script:IncludeDir) {
	$script:IncludeDir = 'c:\lansa\scripts'
}

$ErrorActionPreference = 'Stop'

try {
    #####################################################################################
    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    $temppath = 'c:\temp'
    if ( !(test-path $TempPath) ) {
        New-Item $TempPath -type directory -ErrorAction SilentlyContinue | Out-File $OutputFile -Append
    }

    #####################################################################################
    Write-Output ("$(Log-Date) Fix Windows Server 2019 error 0x800f0950 – Enable .NET 3.5 (error code -2146498224). First occurred 8th June 2022 on AWS. Required for IIS-NetFxExtensibility") | Out-File $OutputFile -Append
    dism /online /enable-feature /featurename:NetFX3 | Out-File $OutputFile -Append

    Write-Output ("$(Log-Date) Installing IIS-NetFxExtensibility") | Out-File $OutputFile -Append
    Run-ExitCode "C:\Windows\system32\dism.exe" @('/online', '/enable-feature', '/featurename:IIS-NetFxExtensibility', '/norestart', '/All')  | Out-File $OutputFile -Append

    Write-Output ("$(Log-Date) Modifying Group Policy")  | Out-File $OutputFile -Append
    Run-ExitCode "$Script:IncludeDir\lgpo.exe" @('/m', "$Script:IncludeDir\lansa.pol")  | Out-File $OutputFile -Append

    Write-Output( "$(Log-Date) Install KB3104002. Enforced by MS Azure MP")  | Out-File $OutputFile -Append
    $Platform = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Platform').Platform
    if ( $Platform -eq "Win2012" ) {
        try {
            $AWSUrl = 'https://lansa.s3-ap-southeast-2.amazonaws.com/3rd+party/Windows8.1-KB3104002-x64.msu'
            $installer_file = (Join-Path $temppath 'Windows8.1-KB3104002-x64.msu')
            (New-Object System.Net.WebClient).DownloadFile($AWSUrl, $installer_file) | Out-File $OutputFile -Append
        } catch {
             throw "Failed to download $AWSUrl from S3"
        }

        $p = Start-Process -FilePath $installer_file -ArgumentList @('/quiet') -Wait -PassThru
        if ( $p.ExitCode -ne 0 ) {
            cmd /c exit $p.ExitCode
            $ErrorMessage = "Windows Update install of $installer_file returned error code $($p.ExitCode)."
            throw $ErrorMessage
        }

        Write-Output "Implement the windows update above by enabling the registry entry HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\ FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING"
        try {
            $AWSUrl = 'https://lansa.s3-ap-southeast-2.amazonaws.com/3rd+party/MicrosoftEasyFix55050.msi'
            $installer_file = (Join-Path $temppath 'MicrosoftEasyFix55050.msi')
            (New-Object System.Net.WebClient).DownloadFile($AWSUrl, $installer_file) | Out-File $OutputFile -Append
        } catch {
             throw "Failed to download $AWSUrl from S3"
        }

        $p = Start-Process -FilePath $installer_file -ArgumentList @('/quiet') -Wait -PassThru
        if ( $p.ExitCode -ne 0 ) {
            cmd /c exit $p.ExitCode
            $ErrorMessage = "MSI install of $installer_file returned error code $($p.ExitCode)."
            throw $ErrorMessage
        }
    }

    Write-Output ("$(Log-Date) Installation completed successfully")  | Out-File $OutputFile -Append

    PlaySound

    # Successful completion so set Last Exit Code to 0
    cmd /c exit 0
}
catch {
	$_ | Out-File $ErrorFile -Append
    Write-Output ("$(Log-Date) Installation error")  | Out-File $ErrorFile -Append
    # Set LASTERRORCODE to a non-0 value
    if ( !$LASTEXITCODE -or $LASTEXITCODE -eq 0 ) {
        cmd /c exit 2
    }
    throw
}
Finally {
    # Produce output so that AWS Run Command Output Viewer gets the text and anything else which sees normal output
    # Errors first so that AWS RUN Command output viewer gets to see it at the top and probably not truuncate it.
    # Note that any errors occurring in functions which call Write-Error may not be captured and may already
    # have been captured by AWS Run Command before all this captured information is output. So, do not presume
    # that the Result Code is on the first line of the output.
    Write-Host "$(Log-Date) Result Code = $LASTEXITCODE"
    Write-Host "$(Log-Date) Logging messages are re-ordered for AWS as errors first. So check time."

    if ( $Cloud -eq 'AWS' ) {
        Get-Content $ErrorFile -ErrorAction SilentlyContinue | Out-Host
        Get-Content $OutputFile -ErrorAction SilentlyContinue | Out-Host
    } else {
        Get-Content $OutputFile -ErrorAction SilentlyContinue | Out-Host
        Get-Content $ErrorFile -ErrorAction SilentlyContinue | Out-Host
    }
    $LASTEXITCODE | Out-File $ResultFile
}

cmd /c exit 0
