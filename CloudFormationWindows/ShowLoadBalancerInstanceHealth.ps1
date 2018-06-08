# Get-ELBInstanceHealth -Region 'us-east-1' -LoadBalancerName 'eval7-WebServerELB-19VOGOIJ3231E'  
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

$Region = 'us-east-1'
$ELBS = @()
Write-Output 'DBWebServerGroup'
$DBWebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'DBWebServerGroup'}
foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
    # Get a list of all the LoadBalancers
    $ELB = Get-ASLoadBalancer -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId
    $ELB.LoadBalancerName
    $ELBs += $ELB
}

Write-Output("Show Load Balancer Status")
foreach ( $ELB in $ELBs ) {
    Write-Output("ELB $($ELB.LoadBalancerName)")
    $ELBInstances = @(Get-ELBInstanceHealth -Region $Region -LoadBalancerName $ELB.LoadBalancerName)
    foreach ( $Instance in $ELBInstances ) {
        if ( $($Instance.State) -eq 'InService' ) {
            $colour = 'White'
        } else {
            $colour = 'Red'
        }
        Write-FormattedOutput "$($Instance.InstanceId) is $($Instance.State)" -ForegroundColor $colour
    }
    Write-Output("")
}