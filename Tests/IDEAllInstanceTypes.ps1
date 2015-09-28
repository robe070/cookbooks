<#
.SYNOPSIS

Use all supported instance types to validate the LANSA IDE supports them.

This tests that the template accepts the instance type only.
Due to resource restrictions, there are failures if an EC2 instance is created for every instance type.
So, if the EC2 instance is launched successfully, the instance is deleted.
Failures are listed

.EXAMPLE


#>
$DebugPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"

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

$ImageIDList = @(  ,("us-east-1", "ami-45750a20" )
             )


# set up environment if not yet setup
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Output "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $script:IncludeDir = "$script:IncludeDir\..\scripts\"

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised"
}


$ErrorCount = 0
$regionlist = Get-AWSRegion
ForEach ( $ImageIDEntry in $ImageIDList ) {
    $region = $ImageIDEntry[0]
    $ImageID = $ImageIDEntry[1] 
    Write-Output "Region $region, Image $ImageID"

    Set-DefaultAWSRegion -Region $region
    Create-Ec2SecurityGroup
    ForEach ( $InstanceType in $InstanceTypes ) {
        try {
            Create-EC2Instance $ImageID $script:keypair $Script:SG -InstanceType $InstanceType

            Stop-EC2Instance -Instance $script:instanceId -Terminate -Force
        }    
        catch {
            $ErrorCount++
            Write-Output "Error using $InstanceType in Region $region using Image $ImageID"
        }
    }
}

if ( $ErrorCount ) {
    Write-Output "$ErrorCount errors"
}