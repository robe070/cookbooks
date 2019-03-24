# Suspen all evaluation stacks to suspend scaling.
"SuspendAllstacks.ps1"

$Region = 'us-east-1'
$WebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $WebServerGroup in $WebServerGroups ) {
    $WebServerGroup.ResourceId

    # Suspend all processes
    Suspend-ASProcess -Region $Region -AutoScalingGroupName $WebServerGroup.ResourceId
}

Write-Output 'DBWebServerGroup'
$DBWebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'DBWebServerGroup'}
foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
    $DBWebServerGroup.ResourceId
    # Suspend all processes
    Suspend-ASProcess -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId
}