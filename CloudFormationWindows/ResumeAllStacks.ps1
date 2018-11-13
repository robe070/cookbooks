# Update all evaluation stacks to resume scaling. Make sure all ELBs have all instances InService BEFORE running this!
"ResumeAllstacks.ps1"

$Region = 'us-east-1'
$WebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $WebServerGroup in $WebServerGroups ) {
    $WebServerGroup.ResourceId

    # Resume all processes
    Resume-ASProcess -Region $Region -AutoScalingGroupName $WebServerGroup.ResourceId
}

Write-Output 'DBWebServerGroup'
$DBWebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'DBWebServerGroup'}
foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
    $DBWebServerGroup.ResourceId
    # Resume all processes
    Resume-ASProcess -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId
}