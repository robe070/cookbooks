<#
.SYNOPSIS

Bake a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>
$script:IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path

# Includes
$Includes = {
        . "$Script:IncludeDir\dot-createlicense.ps1"
        . "$Script:IncludeDir\dot-Add-DirectoryToEnvPathOnce.ps1"
        . "$Script:IncludeDir\dot-New-ErrorRecord.ps1"
        . "$Script:IncludeDir\dot-Send-RemotingFile.ps1"
        . "$script:IncludeDir\dot-CommonTools.ps1"
        . "$script:IncludeDir\dot-AWSTools.ps1"
        . "$script:IncludeDir\dot-DBTools.ps1"
        . "$script:IncludeDir\dot-map-licensetouser.ps1"
        . "$script:IncludeDir\dot-set-accesscontrol.ps1"
        . "$script:IncludeDir\dot-Add-DirectoryToEnvPathOnce.ps1"    
}
&$Includes

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

try
{
    $Script:DialogTitle = "LANSA IDE"
    $script:SG = "bake-ami"
    $script:externalip = $null
    $script:keypair = "RobG_id_rsa"
    $script:keypairfile = "$ENV:USERPROFILE\\.ssh\\id_rsa"
    $script:aminame = "LANSA IDE $(Log-Date)"
    $script:licensekeypassword = $ENV:cloud_license_key
    $script:gitbranch = 'marketplace-and-stt'
    $script:ChefRecipeLocation = "$script:IncludeDir\..\ChefCookbooks"
    $Script:GitRepo = 'lansa'
    $Script:GitRepoPath = "c:\$Script:GitRepo"
    $Script:ScriptTempPath = "c:\temp"
    $Script:LicenseKeyPath = $Script:ScriptTempPath
    $Script:InstanceProfileArn = "arn:aws:iam::775488040364:instance-profile/LansaInstalls_ec2"
    $Script:DVDDir = 'c:\LanDvdCut'

    # Use Forms for a MessageBox
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | out-null

    Create-Ec2SecurityGroup

    # First image found is presumed to be the latest image.
    # Force it into a list so that if one image is returned the variable may be used identically.

    $AmazonImage = @(Get-EC2Image -Filters @{Name = "name"; Values = "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_RTM_Express*"})
    $ImageName = $AmazonImage[0].Name
    $Script:Imageid = $AmazonImage[0].ImageId
    Write-Output "$(Log-Date) Using Base Image $ImageName $Script:ImageId"

    Create-EC2Instance $Script:Imageid $script:keypair $script:SG

    # Remote PowerShell
    # The script below establishes a remote session, invokes a remote command (using Invoke-Command), then cleans up the session. The remote command executed is “Invoke-WebRequest” to obtain the userdata. Since the instance might not be fully initialized, this is tried in a loop.

    $securepassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

    # Wait until PSSession is available
    while ($true)
    {
        "$(Log-Date) Waiting for remote PS connection"
        $session = New-PSSession $Script:publicDNS -Credential $creds -ErrorAction SilentlyContinue
        if ($session -ne $null)
        {
            break
        }

        Sleep -Seconds 10
    }

    Write-Output "$(Log-Date) $Script:instanceid remote PS connection obtained"

    # Simple test of session: 
    # Invoke-Command -Session $session {(Invoke-WebRequest http://169.254.169.254/latest/user-data).RawContent}


    Invoke-Command -Session $session {Set-ExecutionPolicy Unrestricted -Scope CurrentUser}
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -and $remotelastexitcode -ne 0 ) {
        Write-Error "LastExitCode: $remotelastexitcode"
        throw 1
    }    

    # Reflect local variables into remote session
    Execute-RemoteBlock $session {  
        $script:IncludeDir = "$using:GitRepoPath\scripts"
        $DebugPreference = $using:DebugPreference
        $VerbosePreference = $using:VerbosePreference
        $Script:ScriptTempPath = $Using:ScriptTempPath
        $Script:DVDDir = $Using:DVDDir
        $Script:GitRepo = $Using:GitRepo
        $Script:GitRepoPath = $using:GitRepoPath

        Write-Debug "script:IncludeDir = $script:IncludeDir"
        
        # Ensure last exit code is 0. (exit by itself will terminate the remote session)
        cmd /c exit 0
    }

    # Install Chocolatey

    Execute-RemoteScript -Session $session -FilePath "$script:IncludeDir\getchoco.ps1"
    
    # Then we install git using chocolatey and pull down the rest of the files from git

    Execute-RemoteScript -Session $session -FilePath $script:IncludeDir\installGit.ps1 -ArgumentList  @($script:gitbranch, $true)

    # Load utilities into Remote Session.
    # Requires the git repo to be pulled down so the scripts are present.
   
    Execute-RemoteBlock -Session $session -ScriptBlock $Includes

    # Upload files that are not in Git. Should be limited to secure files that must not be in Git.
    # Git is a far faster mechansim for transferring files than using RemotePS.

    Send-RemotingFile $Session "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx" "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx"

    # From now on we may execute scripts which rely on other scripts to be present from the LANSA Cookboks git repo

    Execute-RemoteScript -Session $session -FilePath $script:IncludeDir\install-lansa-base.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath, $script:licensekeypassword)

    # OK and Cancel buttons
    $output = "Please RDP into $Script:publicDNS as Administrator using password '$Script:password' and run Windows Updates. Keep running Windows Updates until it displays the message 'Done Installing Windows Updates. Restart not required'. Now click OK on this message box"
    Write-Output "$(Log-Date) $Output"
    $Response = [System.Windows.Forms.MessageBox]::Show("$Output", $Script:DialogTitle, 1 ) 
    if ( $Response -eq "Cancel" )
    {
        Write-Output "$(Log-Date) $Script:DialogTitle cancelled"
        return -1
    }

    Write-Output "$(Log-Date) Check if Windows Updates has been completed. If it says its retrying in 30s, you still need to run Windows-Updates again using RDP. Type Ctrl-Break, apply Windows Updates and restart this script from the next line."

    # Session has probably been lost due to a Windows Updates reboot

    if ( -not $Session -or ($Session.State -ne 'Opened') )
    {
        Write-Output "$(Log-Date) Session lost or not open. Reconnecting..."
        if ( $Session ) { Remove-PSSession $session }

        # Wait until PSSession is available
        while ($true)
        {
            "$(Log-Date) Waiting for remote PS connection"
            $session = New-PSSession $Script:publicDNS -Credential $creds -ErrorAction SilentlyContinue
            if ($session -ne $null)
            {
                break
            }

            Sleep -Seconds 10
        }

        Write-Output "$(Log-Date) $Script:instanceid remote PS connection obtained"
    }

    # Check that Windows Updates has been completed OK

    Execute-RemoteScript -Session $session -FilePath $script:IncludeDir\win-updates.ps1

    Write-Output "$(Log-Date) Installing IDE"

    Execute-RemoteScript -Session $session -FilePath $script:IncludeDir\install-lansa-ide.ps1

    Write-Output "$(Log-Date) Completing installation steps, except for sysprep"
        
    Execute-RemoteScript -Session $session -FilePath $script:IncludeDir\install-lansa-post-winupdates.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath )

    Invoke-Command -Session $session {Set-ExecutionPolicy restricted -Scope CurrentUser}

    Write-Output "$(Log-Date) Sysprep"
    Invoke-Command -Session $session {cmd /c "$ENV:ProgramFiles\Amazon\Ec2ConfigService\ec2config.exe" -sysprep}

    Remove-PSSession $session

    # Sysprep will stop the Instance

    # Wait for the instance state to be stopped.

    Wait-EC2State $instanceid "Stopped"

    Write-Output "$(Log-Date) Creating AMI"

    $TagDesc = "$($AmazonImage.Description[0]) created on $($AmazonImage.CreationDate[0]) with LANSA IDE installed on $(Log-Date)"
    $AmiName = "$Script:DialogTitle $(Get-Date -format "yyyy-MM-ddTHH-mm-ss")"     # AMI ID must not contain colons
    $amiID = New-EC2Image -InstanceId $Script:instanceid -Name $amiName -Description $TagDesc
    #Start-Sleep -Seconds 120 # For some reason, it can take some time for subsequent calls to Get-EC2Image to return all properties, especially for snapshots. So we wait
 
    $tagName = $amiName # String for use with the name TAG -- as opposed to the AMI name, which is something else and set in New-EC2Image
 
    New-EC2Tag -Resources $amiID -Tags @{ Key = "Name" ; Value = $amiName} # Add tags to new AMI
    
    while ( $true )
    {
        Write-Output "$(Log-Date) Waiting for AMI to become available"
        $amiProperties = Get-EC2Image -ImageIds $amiID

        if ( $amiProperties.ImageState -eq "available" )
        {
            break
        }
        Sleep -Seconds 10
    }
    Write-Output "$(Log-Date) AMI is available"
  
    $amiBlockDeviceMapping = $amiProperties.BlockDeviceMapping # Get Amazon.Ec2.Model.BlockDeviceMapping
  
    $amiBlockDeviceMapping.ebs | `
    ForEach-Object -Process {
        if ( $_ -and $_.SnapshotID )
        {
            New-EC2Tag -Resources $_.SnapshotID -Tags @( @{ Key = "Name" ; Value = $tagName}, @{ Key = "Description"; Value = $tagDesc } )
        }
    }# Add tags to snapshots associated with the AMI using Amazon.EC2.Model.EbsBlockDevice 
    
    # Can't remove security group whilst instance is not terminated
    # return

    #There is a timing thing, so has to retry.
    $err = $true
    while ($err)
    {
        $err = $false
        try
        {
            Remove-EC2SecurityGroup -GroupName $script:SG -Force
        }
        catch
        {
            $err = $true
        }
    }
}
catch
{
    Write-Error ($_ | format-list | out-string)
}