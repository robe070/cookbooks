<#
.SYNOPSIS

Wait for an EC2 instance to reach a desired state.

.EXAMPLE

#>

# Includes
. "$script:IncludeDir\dot-Get-AvailableExceptionsList.ps1"
. "$script:IncludeDir\dot-New-ErrorRecord.ps1"


function Wait-EC2State {
Param (
[parameter(Mandatory=$true)]    [string]$instanceid,
[parameter(Mandatory=$true)]
    [ValidateSet('pending', 'running', 'stopping', 'stopped', 'shutting down','terminated')]
                                [string]$desiredstate,
[parameter(Mandatory=$false)]   [string]$region,
[parameter(Mandatory=$false)]   [decimal]$timeout = 0
)

    try
    {
        # If region not specified then use default region unless thats also null in which case default to Sydney
        if ( -not $region )
        {
            $region = Get-DefaultAWSRegion
            if ( -not $region )
            {
                $region = 'ap-southeast-2'
            }
        }

        # Ensure a valid region is specified
        $regionCheck = Get-AWSRegion $region
        if ( $regionCheck.Name -ne 'Unknown' )
        {
            Set-DefaultAWSRegion $region -ErrorAction Stop
        }
        else
        {
            $errorRecord = New-ErrorRecord System.ArgumentOutOfRangeException RegionDoesNotExist `
                InvalidArgument $region -Message "Region '$region' does not exist."
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Give AWS time to actually create the instance before testing to see if its running yet, otherwise
        # an error will occur trying to locate the instance-id

        if ( $desiredstate -eq 'running' -or $desiredstate -eq 'pending')
        {
            Sleep -Seconds 10
        }

        $Retry = 10     # retry every 10 seconds.
        $UsingTimeout = $false
        if ($Timeout -ne 0){
            $UsingTimeout = $true
            $RetryCount = $Timeout / $Retry
        }
        while ($true)
        {
            if ( $UsingTimeout ) {
                $RetryCount -= 1
                if ($RetryCount -le 0 ){
                    throw "$(Log-Date) Timeout of $Timeout seconds waiting for Desired State = $desiredstate"
                }
            }
            $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid}
            $state = $a.Instances[0].State.Name
            if ($state -eq $desiredstate)
            {
                break;
            }
            Write-Host "$(Log-Date) Current State = $state, Waiting for Desired State = $desiredstate"
            Sleep -Seconds $Retry
        }
    }
    catch
    {
        Write-Error ($_ | format-list | out-string)
        throw
    }
}

<#
.SYNOPSIS

Wait for an EC2 instance to reach a desired state.

.EXAMPLE

#>

# Includes
. "$script:IncludeDir\dot-Get-AvailableExceptionsList.ps1"
. "$script:IncludeDir\dot-New-ErrorRecord.ps1"


function Wait-AzureVMState {
Param (
[parameter(Mandatory=$true)]    [string]$servicename,
[parameter(Mandatory=$true)]    [string]$instanceid,
[parameter(Mandatory=$true)]
    [ValidateSet('pending', 'running', 'stopping', 'stopped', 'shutting down','terminated','not running')]
                                [string]$desiredstate,
[parameter(Mandatory=$false)]   [string]$region
)

    try
    {
        # [ValidateSet('PowerState/Stopped', 'PowerState/Running', 'PowerState/Deallocating', 'PowerState/Deallocated')]
        $RealState = $null
        $Not = $false
        # Note: checking for Stopped is actually checking for not running.
        switch  ($desiredstate) {
            'pending' {$RealState = 'PowerState/pending'; break}
            'running' {$RealState = 'PowerState/running'; break}
            'stopping' {$RealState = 'PowerState/stopping'; break}
            'stopped' {$RealState = 'PowerState/stopped'; break}
            'not running' {$RealState = 'PowerState/running';$Not = $true; break}
            'shutting down' {$RealState = 'PowerState/Deallocating'; break}
            'terminated' {$RealState = 'PowerState/Deallocated'; break}
        }

        # Give Azure time to actually create the instance before testing to see if its running yet, otherwise
        # an error will occur trying to locate the instance-id

        if ( -not $Not -and ($RealState -eq 'PowerState/Running') )
        {
            Sleep -Seconds 10
        }

        while ($true)
        {
            $instance = Get-AzVM -ResourceGroupName $servicename -Name $instanceid -Status
            foreach ($Status in $Instance.Statuses )
            {
                if ( $Not ) {
                    if ( $Status.Code -ne $RealState) {
                        return
                    }
                } elseif ($Status.Code -eq $RealState){
                    return
                }
            }
            "$(Log-Date) Current State = $($Instance.Statuses[1].Code), Waiting for Desired State = $desiredstate"
            Sleep -Seconds 10
        }
    }
    catch
    {
        Write-Error ($_ | format-list | out-string)
        throw
    }
}
