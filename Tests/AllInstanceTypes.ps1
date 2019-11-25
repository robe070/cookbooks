<#
.SYNOPSIS

Use all supported instance types to validate the LANSA Stack supports them.

This tests that the template accepts the instance type only.
Due to resource restrictions, there are failures if a stack is created for every instance type.
So, if the stack is launched successfully, the stack is deleted.
Failures are listed and stacks not removed in order that they may be checked to see whats wrong (But stacks should have failed to launch).

.EXAMPLE


#>

[string[]]$InstanceTypes =                 "c5.large",
"c5.xlarge",
"c5.2xlarge",
"c5.4xlarge",
"c5.9xlarge",
"c5.18xlarge",
"c5d.large",
"c5d.xlarge",
"c5d.2xlarge",
"c5d.4xlarge",
"c5d.9xlarge",
"c5d.18xlarge",
"c5n.large",
"c5n.xlarge",
"c5n.2xlarge",
"c5n.4xlarge",
"c5n.9xlarge",
"c5n.18xlarge",
"d2.xlarge",
"d2.2xlarge",
"d2.4xlarge",
"d2.8xlarge",
"g2.2xlarge",
"g2.8xlarge",
"g3.4xlarge",
"g3.8xlarge",                "i2.xlarge",
"g3.16xlarge",                "i2.xlarge",
"i2.2xlarge",
"i2.4xlarge",
"i2.8xlarge",
"i3.large",
"i3.xlarge",
"i3.2xlarge",
"i3.4xlarge",
"i3.8xlarge",
"i3.16xlarge",                "m5.large",
"i3.metal",                "m5.large",
"m5.xlarge",
"m5.2xlarge",
"m5.4xlarge",
"m5.12xlarge",
"m5.24xlarge",
"m5.metal",
"m5a.large",
"m5a.xlarge",
"m5a.2xlarge",
"m5a.4xlarge",
"m5a.12xlarge",
"m5a.24xlarge",                "m5d.large",
"m5d.xlarge",
"m5d.2xlarge",
"m5d.4xlarge",
"m5d.12xlarge",
"m5d.24xlarge",
"m5d.metal",
"p2.xlarge",
"p2.8xlarge",
"p2.16xlarge",
"p3.2xlarge",
"p3.8xlarge",
"p3.16xlarge",
"t2.nano",
"t2.micro",
"t2.small",
"t2.medium",
"t2.large",
"t2.xlarge",
"t2.2xlarge",
"t3.nano",
"t3.micro",
"t3.small",
"t3.medium",
"t3.large",
"t3.xlarge",
"t3.2xlarge",
"r4.large",
"r4.xlarge",
"r4.2xlarge",
"r4.4xlarge",
"r4.8xlarge",
"r4.16xlarge",
"r5.large",
"r5.xlarge",
"r5.2xlarge",
"r5.4xlarge",
"r5.12xlarge",
"r5.24xlarge",
"r5d.metal",
"r5d.large",
"r5d.xlarge",
"r5d.2xlarge",
"r5d.4xlarge",
"r5d.12xlarge",
"r5d.24xlarge",
"r5d.metal",
"x1.16xlarge",
"x1.32xlarge",
"x1e.xlarge",
"x1e.2xlarge",
"x1e.4xlarge",
"x1e.8xlarge",
"x1e.16xlarge",
"x1e.32xlarge"


$InstanceNumber = 14
$ErrorCount = 0
$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "Region $region"


    ForEach ( $InstanceType in $InstanceTypes )
    {
        try
        {
            Write-Output "$InstanceType"
            New-CFNStack -region $region `
            -StackName "InstanceType$InstanceNumber" `
            -DisableRollback $True `
            -Capability CAPABILITY_IAM `
            -templateURL https://s3-ap-southeast-2.amazonaws.com/lansa/templates/support/L4W14200_scalable/lansa-win-custom.cfn.template `
            -Parameters `
            @{ParameterKey="04DBPassword";ParameterValue="Pcxuser122"}, `
            @{ParameterKey="06WebPassword";ParameterValue="Pcxuser122"}, `
            @{ParameterKey="07KeyName";ParameterValue="RobG_id_rsa"}, `
            @{ParameterKey="08RemoteAccessLocation";ParameterValue="103.231.159.65/32"}, `
            @{ParameterKey="11WebServerInstanceTyp";ParameterValue=$InstanceType}

            Remove-CFNStack -region $region -StackName "InstanceType$InstanceNumber" -Force
        }
        catch
        {
            $_ | Write-Error
            $ErrorCount++
            Write-Output "Error using $InstanceType in Region $region in stack InstanceType$InstanceNumber"
        }

        $InstanceNumber++
    }
}

Write-Output "$ErrorCount errors"
