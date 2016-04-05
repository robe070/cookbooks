$DebugPreference = "SilentlyContinue"
# Get latest SQL Server Web image
$family="SQL Server 2014 SP1 Web on Windows Server 2012 R2"
$image=Get-AzureVMImage | where { $_.ImageFamily -eq $family } | sort PublishedDate -Descending | select -ExpandProperty ImageName -First 1

$subscription = "Main"
$svcName = "baking"
$vmname="BakeIDE140GA2"
$vmsize="Small"
$password = "Pcxuser@122"
$user = "lansa"

$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secPassword)

$vm1 = New-AzureQuickVM -Windows -ServiceName $svcName -Name $VMName -ImageName $image -InstanceSize `
            $vmsize -AdminUsername $user -Password $password -WaitForBoot

# Install the WinRM Certificate first to access the VM via Remote PS
# This REQUIRES PowerShell run Elevated
# Also run Unblock-File .\InstallWinRMCertAzureVM.ps1 => Need close teh Powershell session before it will work.
.\InstallWinRMCertAzureVM.ps1 -SubscriptionName $subscription -ServiceName $svcName -Name $VMName 
 
# Get the RemotePS/WinRM Uri to connect to
$uri = Get-AzureWinRMUri -ServiceName $svcName -Name $VMName 
 
# Enter a remote PS session on the VM
# Enter-PSSession -ConnectionUri $uri -Credential $credential

Write-Output "Create an Image"

Stop-AzureVM -ServiceName $svcName -Name $vmname

Save-AzureVMImage -ServiceName $svcName -Name $vmname -ImageName "sandboximage" -OSState Specialized
                              
#Save a reference to the new image
$sandboxImg = Get-AzureVMImage -ImageName sandboximage
                              
#Set some variables I would use if setting a provisioning configuration
$admin = "localadmin"
$myPwd = "V3ryHardTh!ngT0Gue33"
                              
#Create a new VM config using the new image. Below is assuming the image is not generalized. 
$newVM = New-AzureVMConfig -Name "Sandbox2" -InstanceSize Basic_A1 -ImageName $sandboxImg.ImageName
                              
#If the image had been specialized I would add a provisioning config to command, for example:
#$newVM = New-AzureVMConfig -Name "Sandbox2" -InstanceSize Basic_A1 -ImageName $sandboxImg.ImageName `
#    | Add-AzureProvisioningConfig -Windows -AdminUsername $admin -Password -$myPwd
                              
#Create a new virtual machine based on the above configuration
New-AzureVM -ServiceName $svcName -VMs $newVM -WaitForBoot -Verbose