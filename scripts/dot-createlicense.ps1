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

   # Check if license file is available to be installed
   if ( Test-Path $licenseFile_ )
   {
       try {
           $mypwd = ConvertTo-SecureString -String $password_ -Force –AsPlainText
           Import-PfxCertificate –FilePath $licenseFile_ cert:\\localMachine\\my -Password $mypwd

           #####################################################################################
           Write-Output "$(Log-Date) Save private key filename & current Machine Guid to registry"
           #####################################################################################
           $getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName $dnsName_

           $Thumbprint = $getCert.Thumbprint

           $keyName=(((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName

           New-Item -Path HKLM:\Software\LANSA -ErrorAction SilentlyContinue
           New-ItemProperty -Path HKLM:\Software\LANSA  -Name $registryValue_ -PropertyType String -Value $keyName -Force

           $MachineGuid = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid
           New-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid -PropertyType String -Value $MachineGuid.MachineGuid -force 

           # Write any old junk into the license file to obliterate the contents from the disk so it cannot be recovered
           Get-Process | Out-File $licenseFile_
           #Now delete it from Explorer
           Remove-Item $licenseFile_
        }
        catch {
	        $_
            Write-Error ("$(Log-Date) License Installation error")
            throw        
        }
    }
    else
    {
        Write-Output "$(Log-Date) $LicenseFile_ does not exist. Presume its already installed."
    }
}
