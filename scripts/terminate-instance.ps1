# Terminating the Instance
param (
    [Parameter(Mandatory=$true)]
    [string]
    $versionText,

    [Parameter(Mandatory=$true)]
    [string]
    $version,

    [Parameter(Mandatory=$false)]
    [boolean]
    $DeleteSnapShot=$false
  )


if('$($env:TERMINATEINSTANCE)' -eq 'True') {
   Write-Host "Removing the instance $($env:BUILDIMAGE_INSTANCEID) "
    Remove-EC2Instance -InstanceId $($env:BUILDIMAGE_INSTANCEID) -Force
}
#Removing Vm
Write-Host "Removing the Vm"
Remove-EC2Instance -InstanceId  "$($env:VMTEST_INSTANCEID)" -Force

# Deleting the Security Group
Write-Host "Deleting the security group"
if ( $DeleteSnapShot -eq $true ) {
  Start-Sleep -Seconds 180
   Remove-EC2SecurityGroup -GroupName "$($version)$($versionText)$($env:BUILD_BUILDNUMBER)" -Force
} else {
  Start-Sleep -Seconds 180
   Remove-EC2SecurityGroup -GroupName "$($version)-$($versionText)" -Force
}


if ( $DeleteSnapShot -eq $true ) {
  #Deregister ami and delete snapshot Id
  $ami = "$($env:BUILDIMAGE_AMIID)"
  $snapshot = (Get-EC2Snapshot -owner self | Where-Object {$_.Description -like "*$ami*"}).SnapshotId
  Write-Host "Deregistering the AMI"
  Unregister-EC2Image -ImageId $ami -Force
  Start-Sleep -Seconds 20
  Write-Host "Deleting Snapshot"
  Remove-EC2Snapshot -SnapshotId $snapshot -Force
}
