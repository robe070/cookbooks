# Terminating the Instance
if('$($env:TerminateInstance)' -eq 'True') {
   Write-Host "Removing the instance $($env:BuildImage.InstanceID) "
    Remove-EC2Instance -InstanceId $($env:BuildImage.InstanceID) -Force
}
#Removing Vm
Write-Host "Removing the Vm"
Remove-EC2Instance -InstanceId  $($env:Vmtest.instanceID) -Force

# Deleting the Security Group
Write-Host "Deleting the security group"
Start-Sleep -Seconds 180
 Remove-EC2SecurityGroup -GroupName 'w19d-15-0j$($env:VersionText-w19d-15-0j)$($env:Build_BuildNumber)' -Force

#Deregister ami and delete snapshot Id
$ami = "$($env:BuildImage_amiID)"
$snapshot = (Get-EC2Snapshot -owner self | Where-Object {$_.Description -like "*$ami*"}).SnapshotId
Write-Host "Deregistering the AMI"
Unregister-EC2Image -ImageId $ami -Force
Start-Sleep -Seconds 20
Write-Host "Deleting Snapshot"
Remove-EC2Snapshot -SnapshotId $snapshot -Force
