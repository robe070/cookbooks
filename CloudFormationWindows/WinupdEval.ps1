# Apply windows updates to all evaluation instances
"WinupdEval.ps1"
date

$Region = 'us-east-1'

# *****************************************************************************
# Suspend all processes
# *****************************************************************************

try {
    Write-Output 'WebServerGroup'
    $WebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
    foreach ( $WebServerGroup in $WebServerGroups ) {
        $WebServerGroup.ResourceId
        # Suspend all processes
        Suspend-ASProcess -Region $Region -AutoScalingGroupName $WebServerGroup.ResourceId
    }

    $ELBS = @()
    Write-Output 'DBWebServerGroup'
    $DBWebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'DBWebServerGroup'}
    foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
        $DBWebServerGroup.ResourceId
        # Suspend all processes
        Suspend-ASProcess -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId

        # Keep a list of all the LoadBalancers
        $ELB = Get-ASLoadBalancer -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId
        $ELBs += $ELB
    }

    # *****************************************************************************
    # Run WIndows Updates
    # *****************************************************************************

    Write-Output( "Run Windows Updates on WebServer Group")
    $RunCommand = Send-SSMCommand -Region $Region -DocumentName "AWS-InstallWindowsUpdates" -Target @{Key="tag:aws:cloudformation:logical-id";Values=@("WebServerGroup")} -Parameter @{Action = "Install";AllowReboot="True"; PublishedDaysOld="30"} -comment "Test installing Windows Updates" -TimeoutSecond 600 -MaxConcurrency "50" -MaxError "0"

    $RunCommand = Get-SSMCommand -Region $Region -CommandId $RunCommand.CommandId
    while ( $RunCommand.Status -eq 'InProgress') {
        Write-Output ("WebServerGroup Windows Updates $($RunCommand.Status)")
        Start-Sleep 30
        $RunCommand = Get-SSMCommand -Region $Region -CommandId $RunCommand.CommandId
    }
    Write-Output ("WebServerGroup Windows Updates $($RunCommand.Status)")

    Write-Output( "Run Windows Updates on DBWebServer Group")
    $RunCommand = Send-SSMCommand -Region $Region -DocumentName "AWS-InstallWindowsUpdates" -Target @{Key="tag:aws:cloudformation:logical-id";Values=@("DBWebServerGroup")} -Parameter @{Action = "Install";AllowReboot="True"; PublishedDaysOld="30"} -comment "Test installing Windows Updates" -TimeoutSecond 600 -MaxConcurrency "50" -MaxError "0"

    $RunCommand = Get-SSMCommand -Region $Region -CommandId $RunCommand.CommandId
    while ( $RunCommand.Status -eq 'InProgress') {
        Write-Output ("DBWebServerGroup Windows Updates $($RunCommand.Status)")
        Start-Sleep 30
        $RunCommand = Get-SSMCommand -Region $Region -CommandId $RunCommand.CommandId
    }
    Write-Output ("DBWebServerGroup Windows Updates $($RunCommand.Status)")

    # *****************************************************************************
    # Wait for all instance in ELB to come into service before resuming Auto Scaling Groups
    # *****************************************************************************
    Write-Output("Wait for Load Balancers to be InService")
    foreach ( $ELB in $ELBs ) {
        Write-Output("ELB $($ELB.LoadBalancerName)")
        $ELBInstances = @(Get-ELBInstanceHealth -Region $Region -LoadBalancerName $ELB.LoadBalancerName)
        $AllInService = $false
        while ( -not $AllInService ) {
            $AllInService = $true
            foreach ( $Instance in $ELBInstances ) {
                Write-Output( "$($Instance.InstanceId) is $($Instance.State)")
                if ( $Instance.State -ne 'InService') {
                    $AllInService = $false
                    Write-Output("Waiting")
                    Start-Sleep( 30)
                }
            }
        }
    }

    # *****************************************************************************
    # Resume processes
    # *****************************************************************************

    Write-Output 'Resume All Processes on WebServerGroup'
    foreach ( $WebServerGroup in $WebServerGroups ) {
        $WebServerGroup.ResourceId
        # Resume all processes
        Resume-ASProcess -Region $Region -AutoScalingGroupName $WebServerGroup.ResourceId
    }

    Write-Output 'Resume most processes on DBWebServerGroup'
    foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
        $DBWebServerGroup.ResourceId
        # Resume most processes - Leave ReplaceUnhealthy suspended - Ensure that the instance is not terminated just because it is momentarily being updated.
        Resume-ASProcess -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId -ScalingProcess @("Launch", "AlarmNotification", "HealthCheck", "AZRebalance", "ScheduledActions", "AddToLoadBalancer", "Terminate", "RemoveFromLoadBalancerLowPriority")
    }
} catch {
    Write-Output( "$(date) Windows Update failure. Check Systems Manager Console")  
    cmd /c exit -1
}
Write-Output( "$(date) Windows Update successful.")  
cmd /c exit 0