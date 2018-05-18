# Update all evaluation stacks to resume scaling. Make sure all ELBs have all instances InService BEFORE running this!
"ResumeEvalASGTermination.ps1"
$Region = 'us=east-1'
$stacks = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $stack in $stacks ) {
    $stack.ResourceId
    aws autoscaling resume-processes --region 'us-east-1' --auto-scaling-group-name $stack.ResourceId --scaling-processes Terminate, ReplaceUnhealthy
}

Send-SSMCommand -Region $Region -DocumentName "AWS-InstallWindowsUpdates" -Target @{Key="tag:aws:cloudformation:logical-id";Values=@("WebServerGroup")} -Parameter @{Action = "Install";AllowReboot="True"; PublishedDaysOld="30"} -comment "Test installing Windows Updates" -TimeoutSecond 600 -MaxConcurrency "50" -MaxError "0"