<#
.SYNOPSIS

Bake an Upgrade to a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"
. "$Script:IncludeDir\bake-ide-ami.ps1"

# set up environment if not yet setup
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Output "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised"
}

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Write-Error "$(Log-Date) Not yet been used"

# Update ALL Images which are tagged appropriately

$FilterList = @( @{Name="tag-key"; values="Platform" }
                 @{Name="tag-value"; values=@("Win2012") }
                 @{Name="tag-key"; values="Type" }
                 @{Name="tag-value"; values="Scalable" }
                 @{Name="tag-key"; values="State" }
                 @{Name="tag-value"; values="Current" } )
$AMIList = @(Get-EC2Image -owner self -Filter $FilterList | select-object ImageId, Name, EnaSupport, Tags, CreationDate )
$AMIList | Format-Table

for ($i=0; $i -lt $AMIList.Length; $i++ ) {

    $Platform = $AMIList[$i].Tags | where-object {$_.Key -eq "Platform"}
    $State = $AMIList[$i].Tags | where-object {$_.Key -eq "State"}
    $Type = $AMIList[$i].Tags | where-object {$_.Key -eq "Type"}

    Write-Output ( "$($AMIList[$i].ImageId) $($AMIList[$i].Name)       $($AMIList[$i].EnaSupport) $($Type.Value)  $($Platform.Value)  $($State.Value)         $($AMIList[$i].CreationDate)" )

    $Win2012 = $false
    if ( $Platform.Value -eq "Win2012" ) {
        $Win2012 = $true
    }

    Bake-IdeMsi -VersionText '14.1 EPC1410xx' `
                -VersionMajor 14 `
                -VersionMinor 1 `
                -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\CloudOnly\SPIN0334_LanDVDcut_L4W14100_4138_160727_EPC1410xx" `
                -S3DVDImageDirectory "s3://lansa/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
                -S3VisualLANSAUpdateDirectory "s3://lansa/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
                -S3IntegratorUpdateDirectory "s3://lansa/releasedbuilds/v14/Integrator_L4W14000_latest" `
                -AmazonAMIName $AMIList[$i].Name `
                -GitBranch "support/L4W14100_IDE"`
                -InstallBaseSoftware $false `
                -InstallSQLServer $false `
                -InstallIDE $false `
                -InstallScalable $false `
                -Win2012 $Win2012 `
                -SkipSlowStuff $false `
                -Upgrade $true

    Write-Output "$(Log-Date) Find the new image..."
    # no "State" tag or there is a "State" tag but its set to "Current", and the latest creation date
    $NewImage = @(Get-EC2Image -owner self | where-object {$_.Tags -and ($_.Tags.Key -ne "State" -or ($_.Tags.Key -eq "State" -and $_.Tags.Value -ne "Current")) } | select ImageId, Name, EnaSupport, Tags, CreationDate, Description  | Sort-Object -Descending CreationDate )
    $NewImage[0]

    Write-Output "$(Log-Date) Change state of new image to 'Testing' "
    $State = @{key="State";value="Testing"}
    New-EC2Tag -Resources $NewImage[0].ImageId -Tags @( $Platform, $Type, $State )

    Write-Output "$(Log-Date) Create instance from New AMI for testing. Don't wait."
    $a = New-EC2Instance -ImageId $NewImage[0].ImageId -InstanceType 't2.medium' -KeyName $script:keypair -SecurityGroups $script:SG
    $Instanceid = $a.Instances[0].InstanceId
    New-EC2Tag -Resources $Instanceid -Tags @( @{ Key = "Name" ; Value = $NewImage[0].Name}, $Platform, $Type, $State )
    $Instanceid
                           
    Write-Output "$(Log-Date) Copy AMI to Virginia for submission to AWS Marketplace"
    $amiID = Copy-EC2Image -SourceRegion $ENV:AWS_DEFAULT_REGION  -SourceImageId $NewImage[0].ImageId -Region 'us-east-1' -Name $NewImage[0].Name -Description $NewImage[0].Description
    $amiId

    $AMIName = $NewImage[0].Tags | where-object {$_.Key -eq "Name"}
    New-EC2Tag -Region 'us-east-1' -Resources $amiID -Tags @{ Key = "Name" ; Value = $AMIName.Value}
    $AMIName

    while ( $true )
    {
        Write-Host "$(Log-Date) Waiting for AMI to become available"
        $amiProperties = Get-EC2Image -Region 'us-east-1' -ImageIds $amiID

        if ( $amiProperties.ImageState -eq "available" )
        {
            break
        }
        Start-Sleep -Seconds 10
    }
    Write-Host "$(Log-Date) Virginia AMI is available"

    # Add tags to snapshots associated with the AMI using Amazon.EC2.Model.EbsBlockDevice

    $amiBlockDeviceMapping = $amiProperties.BlockDeviceMapping # Get Amazon.Ec2.Model.BlockDeviceMapping
    $amiBlockDeviceMapping.ebs | `
    ForEach-Object -Process {
        if ( $_ -and $_.SnapshotID )
        {
            New-EC2Tag -Region 'us-east-1' -Resources $_.SnapshotID -Tags @( @{ Key = "Name" ; Value = $NewImage[0].Name}, @{ Key = "Description"; Value = $NewImage[0].Description } )
        }
    } 
}

Write-Host "$(Log-Date) AMI Update complete"