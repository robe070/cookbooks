<#
.SYNOPSIS

Use all supported instance types to validate the LANSA IDE supports them.

This tests that the template accepts the instance type only.
Due to resource restrictions, there are failures if an EC2 instance is created for every instance type.
So, if the EC2 instance is launched successfully, the instance is deleted.
Failures are listed

.EXAMPLE


#>
$DebugPreference = "Continue"
$VerbosePreference = "Continue"


[string[]]$InstanceTypes =                 ,"t2.micro"


$ImageIDList = @(  ("us-east-1", "ami-45750a20" ),
                ("us-west-1", "ami-c945818d" ),
                ("us-west-2", "ami-7b839a4b" ),
                ("eu-west-1", "ami-e99fb19e" ),
                ("eu-central-1", "ami-42dbd85f" ),
                ("ap-northeast-1", "ami-f620b3f6" ),
                ("ap-southeast-1", "ami-bc8a9eee" ),
                ("ap-southeast-2", "ami-51e7a96b" ),
                ("sa-east-1", "ami-b543d7a8")
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