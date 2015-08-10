########################################################################
# PARAMETERS:
#  0. Fully qualified path to license file
#  1. Certificate password
#  2. DNS Name
#  3. Private Key registry value name
########################################################################
function CreateLicence {
   Param (
	   [string]$licenseFile,
	   [string]$password,
	   [string]$dnsName,
	   [string]$registryValue
   )

   # Check if license file is available to be installed
   if ( Test-Path $licenseFile )
   {

       $mypwd = ConvertTo-SecureString -String $password -Force –AsPlainText
       Import-PfxCertificate –FilePath $licenseFile cert:\\localMachine\\my -Password $mypwd

       #####################################################################################
       # Save private key filename & current Machine Guid to registry
       #####################################################################################
       $getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName $dnsName

       $Thumbprint = $getCert.Thumbprint

       $keyName=(((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName

       New-Item -Path HKLM:\Software\LANSA
       New-ItemProperty -Path HKLM:\Software\LANSA  -Name $registryValue -PropertyType String -Value $keyName -Force

       $MachineGuid = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid
       New-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid -PropertyType String -Value $MachineGuid.MachineGuid -force 

       # Write any old junk into the license file to obliterate the contents from the disk so it cannot be recovered
       Get-Process | Out-File $licenseFile
       #Now delete it from Explorer
       Remove-Item $licenseFile
    }
    else
    {
        Write-Output "$(Get-Date -format s) $LicenseFile does not exist. Presume its already installed."
    }
}
