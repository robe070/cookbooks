$mypwd =  ConvertTo-SecureString  -String "4z^32bqzx7q5e8u"  -Force –AsPlainText
$pfxFilePath = "C:\Users\Administrator\Desktop\LansaScalableLicense.pfx"
Import-PfxCertificate  –FilePath  $pfxFilePath  cert:\localMachine\my -Password $mypwd

#####################################################################################
# Save private key filename & current Machine Guid to registry
#####################################################################################
$getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName "LANSA Scalable License"

$Thumbprint = $getCert.Thumbprint

$keyName=(((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName

New-Item -Path HKLM:\Software\LANSA -Force
New-ItemProperty -Path HKLM:\Software\LANSA  -Name ScalableLicensePrivateKey -PropertyType String -Value $keyName -Force

$MachineGuid = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid
New-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid -PropertyType String -Value $MachineGuid.MachineGuid -force

# Write any old junk into the license file to obliterate the contents from the disk so it cannot be recovered
Get-Process | Out-File $pfxFilePath

#Now delete it from Explorer
Remove-Item $pfxFilePath
