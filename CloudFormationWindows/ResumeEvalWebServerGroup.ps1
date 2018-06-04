# Update all evaluation stacks to resume scaling. Make sure all ELBs have all instances InService BEFORE running this!
"ResumeEvalWebServerGroup.ps1"

$Region = 'us-east-1'
$stacks = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $stack in $stacks ) {
    $stack.ResourceId
    Resume-ASProcess -Region $Region -AutoScalingGroupName $stack.ResourceId
}

Write-Output 'DBWebServerGroup'
$DBWebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'DBWebServerGroup'}
foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
    $DBWebServerGroup.ResourceId

    # Resume most processes - Leave ReplaceUnhealthy suspended - Ensure that the instance is not terminated just because it is momentarily being updated.
    # Done this way instead of resuming All and suspending RemoveUnhealthy so that any instances that are unhealthy are not replaced.
    Resume-ASProcess -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId -ScalingProcess @("Launch", "AlarmNotification", "HealthCheck", "AZRebalance", "ScheduledActions", "AddToLoadBalancer", "Terminate", "RemoveFromLoadBalancerLowPriority")
}