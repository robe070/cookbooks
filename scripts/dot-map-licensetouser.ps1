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

    try
    {
        $getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName $certname

        $Thumbprint = $getCert.Thumbprint

        $keyName=(((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName

        if ( -not $keyname )
        {
            Write-Output "No key for $certname"

            $ScalableLicensePrivateKey = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name $regkeyname
            $PriorMachineGuid          = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid
            $MachineGuid               = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid

            if ( -not $ScalableLicensePrivateKey -or -not $PriorMachineGuid -or -not $MachineGuid)
            {
                Write-Error ("One of the following registry keys is invalid: HKLM:\Software\LANSA\$regkeyname, HKLM:\Software\LANSA\PriorMachineGuid, HKLM:\SOFTWARE\Microsoft\Cryptography\MachineGuid")
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
                    Write-Error ("Prior Machine GUID {0} not found at end of Scalable License Private Key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.$regkeyname)
                    throw ("Prior Machine GUID {0} not found at end of Scalable License Private Key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.$regkeyname)
                }

                Write-Verbose ("New private key is {0}" -f $NewScalableLicensePrivateKey)
            }
            else
            {
                Write-Error ( "PriorMachine GUID {0} is not in current LANSA Scalable License Private key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.$regkeyname)
                throw ( "PriorMachine GUID {0} is not in current LANSA Scalable License Private key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.$regkeyname)
            }

            Write-Verbose ("Copy old key to new key")

            $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\"
            $fullPath=$keyPath+$keyName
            Copy-Item $($KeyPath + $ScalableLicensePrivateKey.$regkeyname) $($KeyPath + $NewScalableLicensePrivateKey)

            Write-Verbose ("Set ACLs on new key so that $webuser may access it. If error occurs check that $webuser has been created. If not, password is probably not complex enough.")

            $pkFile = $($KeyPath + $NewScalableLicensePrivateKey)
            $acl=Get-Acl -Path $pkFile
            $permission= $webuser,"Read","Allow"
            $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
            $acl.AddAccessRule($accessRule)
            Set-Acl $pkFile $acl

            Write-Output "User $webuser given access to license $certname"
        }
        else
        {
            Write-Verbose ("Private key $keyname already exists")
        }
    }
    catch
    {
        # Report error but don't abort as one or more licenses may be missing
        Write-Error ($_ | format-list | out-string)
    }
}