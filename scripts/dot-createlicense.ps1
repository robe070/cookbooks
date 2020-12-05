########################################################################
# PARAMETERS:
#  0. Fully qualified path to license file
#  1. Certificate password
#  2. DNS Name
#  3. Private Key registry value name
########################################################################
function CreateLicence {
    param (
        [string]$awsParameterStoreName,
        [string]$dnsName,
        [string]$registryValue
    )
    
    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    if ($Cloud -eq 'AWS') {
        $ReconstitutedFile = "c:\temp\$awsParameterStoreName"
        $Parameter = get-ssmparameter -Name $awsParameterStoreName -WithDecryption $true
        [IO.File]::WriteAllBytes($ReconstitutedFile, [Convert]::FromBase64String($Parameter.Value))
    }
    $licenseFile = "c:\temp\$awsParameterStoreName"
    Write-Host "License File path- $licenseFile"
    # Check if license file is available to be installed
    if ( (Test-Path $licenseFile) -or ($Cloud -eq 'Azure') )
    {
        try {
            if ($Cloud -eq 'AWS') {
                #####################################################################################
                Write-Host "$(Log-Date) $dnsName : install license"
                #####################################################################################
           
                $awspwd = get-ssmparameter -Name 'LicensePrivateKeyPassword' -WithDecryption $true
                $mypwd= ConvertTo-SecureString -String $awspwd.Value -AsPlainText -Force
                Import-PfxCertificate -FilePath $licenseFile cert:\\localMachine\\my -Password $mypwd | Out-Default | Write-Host
                
            }

            #####################################################################################
            Write-Host "$(Log-Date) $dnsName : Save private key filename & current Machine Guid to registry"
            #####################################################################################

            # This call is unreliable and is presumed to be a timing issue as when there is a failure, running this script again works.
            # So, loop until its successful
            while ( [string]::IsNullOrEmpty($getCert.Thumbprint) ) {
                Start-Sleep -Milliseconds 100
                Write-Host("$(Log-Date) Read certificate attempt..." )
                $getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName $dnsName
                $Thumbprint = $getCert.Thumbprint
                Write-Host("$(Log-Date) Thumbprint: $Thumbprint" )
            }

            $keyName = (((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
            if ( [string]::IsNullOrEmpty($keyName) ) {
                throw "Keyname is null or empty"
            }
            Write-Host("$(Log-Date) keyName: $keyName" )

            New-Item -Path HKLM:\Software\LANSA -ErrorAction SilentlyContinue | Out-Default | Write-Host
            New-ItemProperty -Path HKLM:\Software\LANSA  -Name $registryValue -PropertyType String -Value $keyName -Force | Out-Default | Write-Host

            $MachineGuid = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid
            New-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid -PropertyType String -Value $MachineGuid.MachineGuid -force | Out-Default | Write-Host

            if ($Cloud -eq 'AWS') {
            # Write any old junk into the license file to obliterate the contents from the disk so it cannot be recovered
            Get-Process | Out-File $licenseFile

            #Now delete it from Explorer
            Remove-Item $licenseFile | Out-Default | Write-Host
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
        Write-Host "$(Log-Date) $licenseFile does not exist. Presume its already installed."
    }
}
