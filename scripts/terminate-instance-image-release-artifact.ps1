param (
    [Parameter(Mandatory=$true)]
    [string]
    $versionText,

    [Parameter(Mandatory=$true)]
    [string]
    $version
  )

# Terminating the Instance
#Write-Host "Value is $(TerminateInstance)"
if('$($env:TERMINATEINSTANCE)' -eq 'True') {
   Write-Host "Removing the instance $($env:BUILDIMAGE_INSTANCEID) "
    Remove-EC2Instance -InstanceId $($env:BUILDIMAGE_INSTANCEID) -Force
}
#Removing Vm
Write-Host "Removing the Vm"
Remove-EC2Instance -InstanceId  "$($env:VMTEST_INSTANCEID)" -Force

# Deleting the Security Group
Write-Host "Deleting the security group"
Start-Sleep -Seconds 180
 Remove-EC2SecurityGroup -GroupName "$($version)$($versionText)$($env:BUILD_BUILDNUMBER)" -Force
