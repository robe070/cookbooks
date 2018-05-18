# Update all evaluation stacks to suspend scaling
"SuspendEvalASGTermination.ps1"

$stacks = @(Get-ASTag -Region 'us-east-1' -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $stack in $stacks ) {
    $stack.ResourceId
    aws autoscaling suspend-processes --region 'us-east-1' --auto-scaling-group-name $stack.ResourceId --scaling-processes Terminate, ReplaceUnhealthy
}
