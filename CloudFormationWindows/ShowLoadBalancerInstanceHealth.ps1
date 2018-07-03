function Write-FormattedOutput
{
    [CmdletBinding()]
    Param(
         [Parameter(Mandatory=$True,Position=1,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][Object] $Object,
         [Parameter(Mandatory=$False)][ConsoleColor] $BackgroundColor,
         [Parameter(Mandatory=$False)][ConsoleColor] $ForegroundColor
    )    

    # save the current color
    $bc = $host.UI.RawUI.BackgroundColor
    $fc = $host.UI.RawUI.ForegroundColor

    # set the new color
    if($BackgroundColor -ne $null)
    { 
       $host.UI.RawUI.BackgroundColor = $BackgroundColor
    }

    if($ForegroundColor -ne $null)
    {
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
    }

    Write-Output $Object
  
    # restore the original color
    $host.UI.RawUI.BackgroundColor = $bc
    $host.UI.RawUI.ForegroundColor = $fc
}

[Boolean]$ErrorsOnly = $true
[Boolean]$ErrorFound = $false
$Region = 'us-east-1'
$ELBS = @()
Write-Output 'List Load Balancers'
$DBWebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'DBWebServerGroup'}
foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
    # Get a list of all the LoadBalancers
    $ELB = Get-ASLoadBalancer -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId
    $ELB.LoadBalancerName
    $ELBs += $ELB
}

Write-Output("Show Load Balancer Status")
foreach ( $ELB in $ELBs ) {
    $ELBInstances = @(Get-ELBInstanceHealth -Region $Region -LoadBalancerName $ELB.LoadBalancerName)
    [boolean]$FirstInstance = $true
    foreach ( $Instance in $ELBInstances ) {
        if ( $($Instance.State) -eq 'InService' ) {
            $colour = 'White'
        } else {
            $ErrorFound = $true
            $colour = 'Red'
        }
        if ( -not $ErrorsOnly -or $($Instance.State) -ne 'InService' ) {
            if ( $FirstInstance ) {
                $FirstInstance = $false
                Write-Output("ELB $($ELB.LoadBalancerName)")
            }
            Write-FormattedOutput "$($Instance.InstanceId) is $($Instance.State)" -ForegroundColor $colour
        }
    }
    if ( -not $FirstInstance ) {
        Write-Output("")
    }
}

if ( $ErrorFound ) {
    Write-FormattedOutput "ELB Health Check: One or more EC2 instances are not InService" -ForegroundColor 'Red'
} else {
    Write-FormattedOutput "ELB Health Check: All EC2 instances are InService" -ForegroundColor 'Green'
}

Write-Output("Show Auto Scaling Group Health")

# Look at ASG Status too - it can be different when the EC2 instance has been Unhealthy and then becomes Healthy again
$ELBErrorFound = $ErrorFound
$ErrorFound = $false
$ASGInstances = @(Get-ASAutoScalingInstance -Region $Region | where-object {$_.AutoScalingGroupName -like 'eval*' } )
# $ASGInstances | Format-Table
foreach ( $ASGInstance in $ASGInstances ) {
    if ($ASGInstance.HealthStatus -ne 'HEALTHY' ) {
        if ($ELBErrorFound ) {
            $ErrorFound = $true
            Write-FormattedOutput "$($ASGInstance.AutoScalingGroupName) $($ASGInstance.InstanceId) is $($ASGInstance.HealthStatus)" -ForegroundColor 'Red'
        } else {
            Write-FormattedOutput "$($ASGInstance.AutoScalingGroupName) $($ASGInstance.InstanceId) is $($ASGInstance.HealthStatus). Fixing it now..." -ForegroundColor 'Yellow'
            Set-ASInstanceHealth -Region "$Region" -HealthStatus Healthy -InstanceId $ASGInstance.InstanceId -ShouldRespectGracePeriod $true
            Write-FormattedOutput "Run this check again to make sure it worked" -ForegroundColor 'Yellow'
        }
    } elseif ( -not $ErrorsOnly ) {
        Write-FormattedOutput "$($ASGInstance.AutoScalingGroupName) $($ASGInstance.InstanceId) is $($ASGInstance.HealthStatus)" -ForegroundColor 'White'
    }
}

if ( $ErrorFound ) {
    Write-FormattedOutput "ASG Health Check: One or more EC2 instances are not HEALTHY" -ForegroundColor 'Red'
    Write-Output( 'You are stongly advised to consider running this to fix it: ')
    Write-Output( "   Set-ASInstanceHealth -Region '$Region' -HealthStatus Healthy -InstanceId <instance id> -ShouldRespectGracePeriod " + '$false')
    Write-Output( 'In particular it should be resolved before updating stacks and resuming the ReplaceUnhealthy process')
} else {
    Write-FormattedOutput "ASG Health Check: All EC2 instances are HEALTHY" -ForegroundColor 'Green'
}

