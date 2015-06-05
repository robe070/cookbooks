########################################################################
# PARAMETERS:
#  0. Fully qualified path to license file
#  1. Certificate password
#  2. DNS Name
#  3. Private Key registry value name
########################################################################

$mypwd = ConvertTo-SecureString -String $args[1] -Force –AsPlainText
Import-PfxCertificate –FilePath $args[0] cert:\\localMachine\\my -Password $mypwd

#####################################################################################
# Save private key filename & current Machine Guid to registry
#####################################################################################
$getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName $args[2]

$Thumbprint = $getCert.Thumbprint

$keyName=(((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName

New-Item -Path HKLM:\Software\LANSA -Force
New-ItemProperty -Path HKLM:\Software\LANSA  -Name $args[3] -PropertyType String -Value $keyName -Force

$MachineGuid = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid
New-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid -PropertyType String -Value $MachineGuid.MachineGuid -force 

# Write any old junk into the license file to obliterate the contents from the disk so it cannot be recovered
Get-Process | Out-File $args[0]
#Now delete it from Explorer
Remove-Item $args[0]
