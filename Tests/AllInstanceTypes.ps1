<#
.SYNOPSIS

Use all supported instance types to validate the LANSA Stack supports them.

This tests that the template accepts the instance type only.
Due to resource restrictions, there are failures if a stack is created for every instance type.
So, if the stack is launched successfully, the stack is deleted.
Failures are listed and stacks not removed in order that they may be checked to see whats wrong (But stacks should have failed to launch).

.EXAMPLE


#>

[string[]]$InstanceTypes =                 "t2.micro",
                "t2.small",
                "t2.medium",
                "t2.large",
                "m3.medium",
                "m3.large",
                "m3.xlarge",
                "m3.2xlarge",
                "m4.large",
                "m4.xlarge",
                "m4.2xlarge",
                "m4.4xlarge",
                "m4.10xlarge",
                "c3.large",
                "c3.xlarge",
                "c3.2xlarge",
                "c3.4xlarge",
                "c3.8xlarge",
                "c4.large",
                "c4.xlarge",
                "c4.2xlarge",
                "c4.4xlarge",
                "c4.8xlarge",
                "g2.2xlarge",
                "g2.8xlarge",
                "r3.large",
                "r3.xlarge",
                "r3.2xlarge",
                "r3.4xlarge",
                "r3.8xlarge",
                "d2.xlarge",
                "d2.2xlarge",
                "d2.4xlarge",
                "d2.8xlarge",
                "i2.xlarge",
                "i2.2xlarge",
                "i2.4xlarge",
                "i2.8xlarge"

$ErrorCount = 0
$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "Region $region"

    $InstanceNumber = 1

    ForEach ( $InstanceType in $InstanceTypes )
    {
        try
        {
            New-CFNStack -region $region `
            -StackName "InstanceType$InstanceNumber" `
            -DisableRollback $True `
            -Capability CAPABILITY_IAM `
            -templateURL https://s3-ap-southeast-2.amazonaws.com/lansa/templates/lansa-master-win.cfn.template `
            -Parameters `
            @{ParameterKey="4DBPassword";ParameterValue="Pcxuser122"}, `
            @{ParameterKey="6WebPassword";ParameterValue="Pcxuser122"}, `
            @{ParameterKey="7KeyName";ParameterValue="RobG_id_rsa"}, `
            @{ParameterKey="8RemoteAccessLocation";ParameterValue="103.231.159.65/32"}, `
            @{ParameterKey="WebServerInstanceType";ParameterValue=$InstanceType}

            Remove-CFNStack -region $region -StackName "InstanceType$InstanceNumber" -Force
        }    
        catch
        {
            $ErrorCount++
            Write-Output "Error using $InstanceType in Region $region in stack InstanceType$InstanceNumber"
        }

        $InstanceNumber++
    }
}

if ( $ErrorCount )
{
    Write-Output "$ErrorCount errors"
}