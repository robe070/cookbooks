# Update all evaluation stacks to resume scaling. Make sure all ELBs have all instances InService BEFORE running this!
"ResumeEvalWebServerGroup.ps1"

$Region = 'us-east-1'
$stacks = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $stack in $stacks ) {
    $stack.ResourceId
    Resume-ASProcess -Region $Region -AutoScalingGroupName $stack.ResourceId
}
