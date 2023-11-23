<#
.SYNOPSIS

Bake an AMI thats running

.DESCRIPTION

.EXAMPLE


#>

function bake-RunningAMI {
param (
    [Parameter(Mandatory=$true)]
    [string]
    $VersionText,

    [Parameter(Mandatory=$true)]
    [string]
    $LansaVersion,

    [Parameter(Mandatory=$true)]
    [int]
    $VersionMajor,

    [Parameter(Mandatory=$true)]
    [int]
    $VersionMinor,

    [Parameter(Mandatory=$false)]
    [string]
    $Cloud='AWS',

    [Parameter(Mandatory=$false)]
    [string]
    $Language='ENG',

    [Parameter(Mandatory=$false)]
    [boolean]
    $RunWindowsUpdates=$false,          # Generally, not required to run Windows Updates because we are using the latest VM Image

    [Parameter(Mandatory=$false)]
    [boolean]
    $ManualWinUpd=$false,

    [Parameter(Mandatory=$false)]
    [string]
    $Title,

    [Parameter(Mandatory=$true)]
    [string]
    $KeyPairPath,

    [Parameter(Mandatory=$false)]
    [switch]
    $Pipeline

    )

#Requires -RunAsAdministrator


Write-Host "Cloud: $Cloud"

# set up environment if not yet setup
if ( (Test-Path variable:IncludeDir))
{
    # Log-Date can't be used yet as Framework has not been loaded

    Write-Host "Initialising environment - presumed not running through RemotePS"

    # $MyInvocation.MyCommand.Path
	# $script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	throw '$IncludeDir must be set up by the caller'
}

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

if ( $Title ) {
    $Script:DialogTitle = $Title
    $script:instancename = "$Title $VersionText installed on $(Log-Date)"
} else {
    $Script:DialogTitle = "LANSA Save Image"
    $script:instancename = "LANSA Save Image $VersionText installed on $(Log-Date)"
}

Write-Host ("$(Log-Date) DialogTitle = $($Script:DialogTitle) instancename = $($Script:instancename)")

try
{
    # Clear out the msgbox object in case its been run already
    $Script:msgbox = $null

    Write-Host ("$(Log-Date) Allow Remote Powershell session to any host. If it fails you are not running as Administrator!")
    $VerbosePreferenceSaved = $VerbosePreference
    $VerbosePreference = "SilentlyContinue"
    enable-psremoting -SkipNetworkProfileCheck -force
    set-item wsman:\localhost\Client\TrustedHosts -value * -force
    $VerbosePreference = $VerbosePreferenceSaved
    $externalip = Get-ExternalIP

    Write-Host( "$(Log-Date) Host machine WinRM settings:")
    winrm get winrm/config/winrs

    if ( $VersionText -like "w12*" ) {
        $Platform = 'Win2012'
        $Win2012 = $true
    } elseif ($VersionText -like "w16*") {
        $Platform = 'Win2016'
        $Win2012 = $false
    } elseif ($VersionText -like "w19*"){
        $Platform= 'Win2019'
        $Win2012 = $false
    } else {
        throw 'VersionText must start with one of the following: w12, w16 or w19'
    }

    Write-Host "Language = $Language, Platform = $Platform"

    Write-Host( "$(Log-Date) Region to us-east-1" )
    Set-DefaultAWSRegion -Region us-east-1

    if ( $Cloud -eq 'AWS' ) {
        Write-Host( "$(Log-Date) Locating existing instance...")
        $TaggedInstances = @(Get-EC2Tag -Filter @{Name="tag:BakeVersion";Values=$VersionText} | Where-Object ResourceType -eq "instance")
        if ( $TaggedInstances ) {
            $TaggedInstances[0] | Format-List *
            if ( $TaggedInstances.Count -eq 1 ) {
                $AdminUserName = "Administrator"
                $InstanceId = $TaggedInstances[0].ResourceId
                $Script:instanceid = $InstanceId
                Write-Host( "$(Log-Date) Using Instance Id = $instanceId")
                $Script:password = Get-EC2PasswordData -InstanceId $instanceid -PemFile $script:keypairfile -Decrypt

                $a = (Get-EC2Instance -InstanceID $instanceid)
                $Script:publicDNS = $a.Instances[0].PublicDnsName
                $Script:Imageid = $a.Instances[0].ImageId
                $AmazonImage = Get-Ec2Image -ImageId $Script:Imageid
                $ImageName = $AmazonImage[0].Name
                Write-Host "$(Log-Date) Using Base Image $ImageName $Script:ImageId"

                Write-Host( "$(Log-Date) Using PublicDnsName = $Script:publicDNS")

                $Script:vmname = "Bake $Script:instancename"
            } else {
                throw "There are $TaggedInstances.Count instances tagged BakeVersion=$VersionText. Cannot bake image. Ensure there is 1 and only 1 VM running with the tag"
            }
        } else {
            throw "There are 0 instances tagged BakeVersion=$VersionText. Cannot bake image. Ensure there is 1 and only 1 VM running with the tag"
        }
    } else {
        throw Script does not support baking an Azure image
    }

    # Remote PowerShell
    Write-Host( "$(Log-Date) User Id:$AdminUserName Password: $Script:password")
    $securepassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($AdminUserName, $securepassword)
    Connect-RemoteSession

    Write-Host "$(Log-Date) Sysprep"
    Write-Host "Use Invoke-Command as the Sysprep will terminate the instance and thus Execute-RemoteBlock will return a fatal error"

    try {
        if ( $Cloud -eq 'AWS' ) {
            if ( $Win2012 ) {
                Write-Host "$(Log-Date) AWS sysprep for Win2012"
                Invoke-Command -Session $Script:session {cmd /c "$ENV:ProgramFiles\Amazon\Ec2ConfigService\ec2config.exe" -sysprep  | Out-Default | Write-Host}
            } else {
               $EC2LaunchV1Path = "$ENV:ProgramData\Amazon\EC2-Windows\Launch\Scripts"
               if ( -not (Test-Path $EC2LaunchV1Path )) {
                  Write-Host "$(Log-Date) EC2 Launch V2 AWS sysprep for Win2016+"
                  # See here for doco - http://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch.html
                  Invoke-Command -Session $Script:session {
                     Set-Location "$env:SystemRoot\panther"  | Out-Default | Write-Host;
                     $filename = "unattend.xml"
                     if (Test-Path $filename)
                     {
                           Write-Host( "$(Log-Date) Deleting $filename")
                           Remove-Item $filename | Out-Default | Write-Host;
                     }
                     $filename = "WaSetup.xml"
                     if (Test-Path $filename )
                     {
                           Write-Host( "$(Log-Date) Deleting $filename")
                           Remove-Item $filename | Out-Default | Write-Host;
                     }
                  }
                  Invoke-Command -Session $Script:session {. "$ENV:programfiles\amazon\ec2launch\ec2launch.exe" sysprep --shutdown=true --clean=true | Out-Default | Write-Host}
               } else {
                  Write-Host "$(Log-Date) EC2 Launch V1 AWS sysprep for Win2016+"
                  # See here for doco - http://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch.html
                  Invoke-Command -Session $Script:session {
                     Set-Location "$env:SystemRoot\panther"  | Out-Default | Write-Host;
                     $filename = "unattend.xml"
                     if (Test-Path $filename)
                     {
                           Write-Host( "$(Log-Date) Deleting $filename")
                           Remove-Item $filename | Out-Default | Write-Host;
                     }
                     $filename = "WaSetup.xml"
                     if (Test-Path $filename )
                     {
                           Write-Host( "$(Log-Date) Deleting $filename")
                           Remove-Item $filename | Out-Default | Write-Host;
                     }
                  }
                  Invoke-Command -Session $Script:session {cd $EC2LaunchV1Path | Out-Default | Write-Host}
                  Invoke-Command -Session $Script:session {./InitializeInstance.ps1 -Schedule | Out-Default | Write-Host}
                  Invoke-Command -Session $Script:session {./SysprepInstance.ps1 | Out-Default | Write-Host}
               }
            }
        } elseif ($Cloud -eq 'Azure' ) {
            Write-Host( "$(Log-Date) Running sysprep automatically")

            Invoke-Command -Session $Script:session {
                Set-Location "$env:SystemRoot\panther"  | Out-Default | Write-Host;
                $filename = "unattend.xml"
                if (Test-Path $filename)
                {
                    Write-Host( "$(Log-Date) Deleting $filename")
                    Remove-Item $filename | Out-Default | Write-Host;
                }
                $filename = "WaSetup.xml"
                if (Test-Path $filename )
                {
                    Write-Host( "$(Log-Date) Deleting $filename")
                    Remove-Item $filename | Out-Default | Write-Host;
                }
                Set-Location "$env:SystemRoot\system32\sysprep"  | Out-Default | Write-Host;
                $unattend = 'c:\lansa\sysprep\Unattend.xml'
                if ( Test-Path $unattend) {
                    Write-Host( "$(Log-Date) sysprep using language unattend file")
                    Get-Content $unattend | Out-default | Write-Host
                    cmd /c sysprep /oobe /generalize /shutdown /unattend:$unattend | Out-Default | Write-Host;
                } else {
                    Write-Host( "$(Log-Date) sysprep WITHOUT unattend file")
                    cmd /c sysprep /oobe /generalize /shutdown | Out-Default | Write-Host;
                }
            }
        }
    } catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
        Write-Host( "$(Log-Date) Ignore the exception 'The I/O operation has been aborted because of either a thread exit or an application request', presuming that its just an artifact of the sysprep terminating the instance")
    } catch {
        Write-RedOutput $_ | Out-Default | Write-Host
        Write-RedOutput $_.exception | Out-Default | Write-Host
        Write-RedOutput $_.exception.GetType().fullname | Out-Default | Write-Host
        $Response = MessageBox "Do you want to continue building the image?" 0x3 -Pipeline:$Pipeline
        $Response
        if ( $response -ne 0x6 ) {
            throw "Sysprep script failure"
        }
    }

    # Sysprep will stop the Instance

    Write-Host( "$(Log-Date) Wait for the instance state to be stopped...")

    if ($Cloud -eq 'AWS') {
        # Wait for the instance state to be stopped.

        Wait-EC2State $instanceid "Stopped" -timeout 300 | Out-Default | Write-Host     # Should take 40 seconds or less to stop

        # Refer to Azure code above as to why this is necessary for Azure. It may make a difference for the failures we see in AWS too.
        try {
            while ($true) {
                Write-Host "$(Log-Date) (from Host) Waiting for VM to be fully stopped..."
                Start-Sleep -Seconds 5
                Invoke-Command -Session $Script:session {
                    Write-Host "$(Log-Date) (from VM) VM is still running..."
                }
            }
        } catch {
            # A failure to execute the log message on the VM is presumed to indicate that the VM is fully stopped and the image may be taken.
            Write-Host "$(Log-Date) VM has fully stopped"
        }
        Remove-PSSession $Script:session | Out-Default | Write-Host

        Write-Host "$(Log-Date) Creating AMI"

        # Updates already have LANSA-appended text so strip it off if its there
        $SimpleDesc = $($AmazonImage[0].Description)
        $Index = $SimpleDesc.IndexOf( "created on" )
        if ( $index -eq -1 ) {
            $FinalDescription = $SimpleDesc
        } else {
            $FinalDescription = $SimpleDesc.substring( 0, $index - 1 )
        }

        $TagDesc = "$FinalDescription created on $($AmazonImage[0].CreationDate) with LANSA $Language $VersionText installed on $(Log-Date)"
        $AmiName = "$Script:DialogTitle $VersionText $(Get-Date -format "yyyy-MM-ddTHH-mm-ss") $Platform"     # AMI ID must not contain colons
        $amiID = New-EC2Image -InstanceId $Script:instanceid -Name $amiName -Description $TagDesc

        $tagName = $amiName # String for use with the name TAG -- as opposed to the AMI name, which is something else and set in New-EC2Image

        New-EC2Tag -Resources $amiID -Tags @( @{ Key = "Name" ; Value = $amiName}, @{ Key = "LansaVersion"; Value = $LansaVersion } ) | Out-Default | Write-Host

        while ( $true )
        {
            Write-Host "$(Log-Date) Waiting for AMI to become available"
            $amiProperties = Get-EC2Image -ImageIds $amiID

            if ( $amiProperties.ImageState -eq "available" )
            {
                break
            }
            Sleep -Seconds 10
        }
        Write-Host "$(Log-Date) AMI $amiID is available"
        if($Pipeline) {
            Write-Host "##vso[task.setvariable variable=instanceID;isOutput=true]$instanceid"
            Write-Host "##vso[task.setvariable variable=amiID;isOutput=true]$amiID"
        }

        # Add tags to snapshots associated with the AMI using Amazon.EC2.Model.EbsBlockDevice

        $amiBlockDeviceMapping = $amiProperties.BlockDeviceMapping # Get Amazon.Ec2.Model.BlockDeviceMapping
        $amiBlockDeviceMapping.ebs | `
        ForEach-Object -Process {
            if ( $_ -and $_.SnapshotID )
            {
                New-EC2Tag -Resources $_.SnapshotID -Tags @( @{ Key = "Name" ; Value = $tagName}, @{ Key = "Description"; Value = $tagDesc }, @{ Key = "LansaVersion"; Value = $LansaVersion } )  | Out-Default | Write-Host
            }
        }

        Write-Host( "$(Log-Date) Terminating VM")
        Remove-EC2Instance -InstanceId $instanceid -Force | Out-Default | Write-Host
        Wait-EC2State $instanceid "Terminated"
    }

    # $dummy = MessageBox "Image bake successful" 0 -Pipeline:$Pipeline
    return "Success"
}
catch
{
    . "$Script:IncludeDir\dot-catch-block.ps1"

    Write-Host 'Tidying up'
    if ( Test-Path variable:Script:session ) {
        Remove-PSSession $Script:session | Out-Default | Write-Host
    }

    $dummy = MessageBox "Image bake failed. Fatal error has occurred. Click OK and look at the console log" 0 -Pipeline:$Pipeline

    # Fail the build on exception
    if ($Pipeline) {
        #In AWS, if image bake fails , retry functionality is implemented. So failed instance need  to be removed
        if($Cloud -eq 'AWS'){
            Remove-EC2Instance -InstanceId $instanceid -Force
            Start-Sleep -Seconds 150
        }
        throw $_.Exception
    }
    return "Failure"# 'Return' not 'throw' so any output thats still in the pipeline is piped to the console
}

}

# Setup default account details
# This code is rarely required and is more for documentation.
function SetUpAccount {
    # Subscription Name was rejected by Select-AzureSubscription so Subscription Id was used instead.
    $subscription = "edff5157-5735-4ceb-af94-526e2c235e80"
    $Storage = "lansalpcmsdn"
    Select-AzureSubscription -SubscriptionId $subscription
    set-AzureSubscription -SubscriptionId $subscription -CurrentStorageAccount $Storage
}

