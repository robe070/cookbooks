<#
.SYNOPSIS

Create new private key filename for new machine GUID
New key is just a copy of the old one with a change of name to replace the old Machine GUID with the new Machine GUID

Value for the old private key is stored in the registry key HKLM:\Software\LANSA\ScalableLicensePrivateKey
Value for the old Machine GUID is stored in the registry key HKLM:\Software\LANSA\PriorMachineGuid
Format of private key file name is <Unique for certificate no matter where it is imported to>_<Machine GUID>

Requires the environment that a LANSA Cake provides, particularly an AMI license.


.EXAMPLE
Map-LicenseToUser "LANSA Scalable License" "ScalableLicensePrivateKey" "PCXUSER2"
Map-LicenseToUser "LANSA Integrator License" "IntegratorLicensePrivateKey" "PCXUSER2"
Map-LicenseToUser "LANSA Development License" "DevelopmentLicensePrivateKey" "PCXUSER2"

#>
function Map-LicenseToUser {
    Param (
        [string]$certname,
        [string]$regkeyname,
        [string]$webuser
    )
 
    Import-Module "$($script:IncludeDir)\Modules\NTFSSecurity"
 
    try
    {
        $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\"

        $getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName $certname

        if ( -not $getCert ) {
            throw "$(Log-Date) $certname certificate not found"
        }

        $Thumbprint = $getCert.Thumbprint

        $PrivateKey = ((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey)
        if ( $PrivateKey ) {
            $NewScalableLicensePrivateKey  =($privateKey.CspKeyContainerInfo).UniqueKeyContainerName
        }

        if ( -not $PrivateKey -or -not $NewScalableLicensePrivateKey) {
            Write-Output "No key for $certname"

            $ScalableLicensePrivateKey = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name $regkeyname
            $PriorMachineGuid          = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid
            $MachineGuid               = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid

            # Workaround for when ScalableLicense Image 14.1 EPC 141031 on AWS had an empty value for the Integrator private key
            if ( $ScalableLicensePrivateKey -and -not $ScalableLicensePrivateKey.$regkeyname ) {
                Set-ItemProperty -Path HKLM:\Software\LANSA  -Name $regkeyname -Value '70b31c86f62ce70b122c67984981a890_aed32363-64f4-4406-b5ad-ff5841643ff5' -Force
                $ScalableLicensePrivateKey = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name $regkeyname
            }

            if ( -not $ScalableLicensePrivateKey -or -not $ScalableLicensePrivateKey.$regkeyname `
             -or -not $PriorMachineGuid -or -not $PriorMachineGuid.PriorMachineGuid `
             -or -not $MachineGuid -or -not $MachineGuid.MachineGuid)
            {
                Write-Output ("")
                Write-Output ("ScalableLicensePrivateKey=")
                Write-Output ("Begin")
                Write-Output $ScalableLicensePrivateKey | fl
                Write-Output ("End")
                Write-Output ("PriorMachineGuid=")
                Write-Output ("Begin")
                Write-Output $PriorMachineGuid | fl
                Write-Output ("End")
                Write-Output ("MachineGuid=")
                Write-Output ("Begin")
                Write-Output $MachineGuid | fl
                Write-Output ("End")
                Write-Output ("")
                throw ("One of the following registry keys is invalid: HKLM:\Software\LANSA\$regkeyname, HKLM:\Software\LANSA\PriorMachineGuid, HKLM:\SOFTWARE\Microsoft\Cryptography\MachineGuid")
            }

            Write-Verbose ("Replace Old Machine Guid with new Machine Guid")

            if ( ($ScalableLicensePrivateKey.$regkeyname -match $PriorMachineGuid.PriorMachineGuid) -eq $true )
            {
                Write-Verbose "Guid found in Private Key"
                $NewScalableLicensePrivateKey = $ScalableLicensePrivateKey.$regkeyname -replace 
                                                    $($PriorMachineGuid.PriorMachineGuid + "$"), $MachineGuid.MachineGuid
                if ($ScalableLicensePrivateKey.$regkeyname -eq $NewScalableLicensePrivateKey)
                {
                    throw ("Prior Machine GUID {0} not found at end of Scalable License Private Key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.$regkeyname)
                }

                Write-Verbose ("New private key is {0}" -f $NewScalableLicensePrivateKey)
            }
            else
            {
                throw ( "PriorMachine GUID {0} is not in current LANSA Scalable License Private key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.$regkeyname)
            }

            Write-Verbose ("Copy old key to new key")

            # $fullPath=$keyPath+$keyName
            Copy-Item $($KeyPath + $ScalableLicensePrivateKey.$regkeyname) $($KeyPath + $NewScalableLicensePrivateKey)

            # Set ownership of file to Local Admin Group rather than SYSTEM which is typically the current account when CloudFormation runs the script
            # And if its not changed, then re-running this script manually as Administrator fails when attempting to set the ACLs - see below
            takeown /a /f $($KeyPath + $NewScalableLicensePrivateKey)
            # And then give Admins FullControl
            get-item $($KeyPath + $NewScalableLicensePrivateKey) |  Add-NTFSAccess -account 'BUILTIN\Administrators' -AccessRights FullControl            
        }
        else {
            Write-Verbose ("Private key $NewScalableLicensePrivateKey already exists. Ensure $webuser can access it")
        }


        Write-Verbose ("Set ACLs on new key so that $webuser may access it. If error occurs check that $webuser has been created. If not, password is probably not complex enough.")

        $pkFile = $($KeyPath + $NewScalableLicensePrivateKey)
        $acl=Get-Acl -Path $pkFile
        $permission= $webuser,"Read","Allow"
        $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.AddAccessRule($accessRule)
        Set-Acl $pkFile $acl

        Write-GreenOutput "User $webuser given access to license $certname"
    }
    catch
    {
        Write-RedOutput ($_ | format-list | out-string)
        Write-Output ("")
        throw
    }
}