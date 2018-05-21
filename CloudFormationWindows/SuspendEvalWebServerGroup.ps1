# Update all WebServerGroup evaluation stacks to suspend scaling
"SuspendEvalASGTermination.ps1"

$Region = 'us-east-1'
$stacks = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $stack in $stacks ) {
    $stack.ResourceId
    # aws autoscaling suspend-processes --region $Region --auto-scaling-group-name $stack.ResourceId --scaling-processes Terminate, ReplaceUnhealthy
    # Suspend all processes
    Suspend-ASProcess -AutoScalingGroupName $stack.ResourceId
}
