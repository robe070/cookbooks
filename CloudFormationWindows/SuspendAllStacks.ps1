# Suspen all evaluation stacks to suspend scaling.
Param(
    [Parameter(Mandatory)]
        [ValidateSet('All','KeepAlive','Custom')]
        [string] $ScalingProcesses
)

"SuspendAllstacks.ps1"

[System.Collections.ArrayList]$ProcessList = @()


switch ( $ScalingProcesses ) {
    'All' {
        # Do nothing - use empty list
    }
    'KeepAlive' {
        $ProcessList = @("Terminate", "ReplaceUnhealthy")
    }
    'Custom' {
        # Edit this to what ever you need
        $ProcessList = @("Terminate", "ReplaceUnhealthy")
    }
}

$Region = 'us-east-1'
$WebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'WebServerGroup'}
foreach ( $WebServerGroup in $WebServerGroups ) {
    $WebServerGroup.ResourceId

    # Suspend processes which may cause EC2 instance to be terminated
    Suspend-ASProcess -Region $Region -AutoScalingGroupName $WebServerGroup.ResourceId -ScalingProcess $ProcessList
}

Write-Output 'DBWebServerGroup'
$DBWebServerGroups = @(Get-ASTag -Region $Region -Filter @( @{ Name="key"; Values=@("aws:cloudformation:logical-id") } )) | Where-Object {$_.Value -eq 'DBWebServerGroup'}
foreach ( $DBWebServerGroup in $DBWebServerGroups ) {
    $DBWebServerGroup.ResourceId
    # Suspend processes which may cause EC2 instance to be terminated
    Suspend-ASProcess -Region $Region -AutoScalingGroupName $DBWebServerGroup.ResourceId -ScalingProcess $ProcessList
}