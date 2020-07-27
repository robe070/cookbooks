########################################################################
# PARAMETERS:
#  0. Fully qualified path to license file
#  1. Certificate password
#  2. DNS Name
#  3. Private Key registry value name
########################################################################
function CreateLicence {
    Param (
        [string]$licenseFile_,
        [string]$password_,
        [string]$dnsName_,
        [string]$registryValue_
    )

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    # Check if license file is available to be installed
    if ( Test-Path $licenseFile_ -or $Cloud -eq 'Azure' )
    {
        try {
            if ($Cloud -eq 'AWS') {
            #####################################################################################
            Write-Host "$(Log-Date) $dnsName_ : install license"
            #####################################################################################

            $mypwd = ConvertTo-SecureString -String $password_ -Force -AsPlainText
            Import-PfxCertificate -FilePath $licenseFile_ cert:\\localMachine\\my -Password $mypwd | Write-Host
            }

            #####################################################################################
            Write-Host "$(Log-Date) $dnsName_ : Save private key filename & current Machine Guid to registry"
            #####################################################################################

            # This call is unreliable and is presumed to be a timing issue as when there is a failure, running this script again works.
            # So, loop until its successful
            while ( [string]::IsNullOrEmpty($getCert.Thumbprint) ) {
                Start-Sleep -Milliseconds 100
                Write-Host("$(Log-Date) Read certificate attempt..." )
                $getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName $dnsName_
                $Thumbprint = $getCert.Thumbprint
                Write-Host("$(Log-Date) Thumbprint: $Thumbprint" )
            }

            $keyName = (((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
            if ( [string]::IsNullOrEmpty($keyName) ) {
                throw "Keyname is null or empty"
            }
            Write-Host("$(Log-Date) keyName: $keyName" )

            New-Item -Path HKLM:\Software\LANSA -ErrorAction SilentlyContinue | Write-Host
            New-ItemProperty -Path HKLM:\Software\LANSA  -Name $registryValue_ -PropertyType String -Value $keyName -Force | Write-Host

            $MachineGuid = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid
            New-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid -PropertyType String -Value $MachineGuid.MachineGuid -force | Write-Host

            if ($Cloud -eq 'AWS') {
            # Write any old junk into the license file to obliterate the contents from the disk so it cannot be recovered
            Get-Process | Out-File $licenseFile_

            #Now delete it from Explorer
            Remove-Item $licenseFile_ | Write-Host
            }
         }
         catch {
             $_ | Write-Host
             throw ("$(Log-Date) License installation error")
         }
         Write-Host "$(Log-Date) License installation succeeded."
     }
     else
     {
         Write-Host "$(Log-Date) $LicenseFile_ does not exist. Presume its already installed."
     }
 }
