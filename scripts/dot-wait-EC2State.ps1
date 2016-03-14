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
[parameter(Mandatory=$false)]   [string]$region
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

        # Give AWS time to actually crfteate the instance before testing to see if its running yet, otherwise 
        # an error will occur trying to locate the instance-id

        if ( $desiredstate -eq 'running' -or $desiredstate -eq 'pending')
        {
            Sleep -Seconds 10
        }

        while ($true)
        {
            $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid}
            $state = $a.Instances[0].State.Name
            if ($state -eq $desiredstate)
            {
                break;
            }
            "$(Log-Date) Current State = $state, Waiting for Desired State = $desiredstate"
            Sleep -Seconds 10
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
    [ValidateSet('provisioning', 'readyrole', 'stoppeddeallocated', 'stoppedvm', 'creatingvm')]
                                [string]$desiredstate,
[parameter(Mandatory=$false)]   [string]$region
)

    try
    {
        # Give Azure time to actually create the instance before testing to see if its running yet, otherwise 
        # an error will occur trying to locate the instance-id

        if ( $desiredstate -eq 'readyrole')
        {
            Sleep -Seconds 10
        }

        while ($true)
        {
            $instance = Get-AzureVM -ServiceName $servicename -Name $instanceid
            if ($instance.InstanceStatus -eq $desiredstate)
            {
                break;
            }
            "$(Log-Date) Current State = $($instance.InstanceStatus), Waiting for Desired State = $desiredstate"
            Sleep -Seconds 10
        }
    }
    catch
    {
        Write-Error ($_ | format-list | out-string)
        throw
    }
}
