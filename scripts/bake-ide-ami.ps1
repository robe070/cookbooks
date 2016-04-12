<#
.SYNOPSIS

Bake a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>

function bake-IdeMsi {
param (
    [Parameter(Mandatory=$true)]
    [string]
    $VersionText,
    
    [Parameter(Mandatory=$true)]
    [int]
    $VersionMajor,

    [Parameter(Mandatory=$true)]
    [int]
    $VersionMinor,

    [Parameter(Mandatory=$true)]
    [string]
    $LocalDVDImageDirectory,

    [Parameter(Mandatory=$true)]
    [string]
    $S3DVDImageDirectory,

    [Parameter(Mandatory=$true)]
    [string]
    $S3VisualLANSAUpdateDirectory,

    [Parameter(Mandatory=$true)]
    [string]
    $S3IntegratorUpdateDirectory,

    [Parameter(Mandatory=$true)]
    [string]
    $AmazonAMIName,

    [Parameter(Mandatory=$true)]
    [string]
    $GitBranch,

    [Parameter(Mandatory=$false)]
    [string]
    $AdminUserName='Administrator',

    [Parameter(Mandatory=$false)]
    [string]
    $Language='ENG',

    [Parameter(Mandatory=$false)]
    [boolean]
    $InstallSQLServer=$false,

    [Parameter(Mandatory=$false)]
    [boolean]
    $InstallIDE=$true,

    [Parameter(Mandatory=$false)]
    [boolean]
    $InstallBaseSoftware=$true,

    [Parameter(Mandatory=$false)]
    [string]
    $Cloud='AWS'
    )

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

$Script:DialogTitle = "LANSA IDE"
$script:instancename = "LANSA IDE $VersionText installed on $(Log-Date)"

try
{
    # Use Forms for a MessageBox
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | out-null

    Write-Output ("$(Log-Date) Upload any changes to current installation image")

    Write-Verbose ("Test if source of DVD image exists")
    if ( !(Test-Path -Path $LocalDVDImageDirectory) )
    {
        $errorRecord = New-ErrorRecord System.IO.FileNotFoundException  ObjectNotFound `
            ObjectNotFound $LocalDVDImageDirectory -Message "LocalDVDImageDirectory '$LocalDVDImageDirectory' does not exist."
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    if ( $Cloud -eq 'AWS' ) {
        # Standard arguments. Triple quote so we actually pass double quoted parameters to aws S3
        # MSSQLEXP excludes ensure that just 64 bit english is uploaded.
        [String[]] $S3Arguments = @("""--exclude""", """*ibmi/*""", """--exclude""", """*AS400/*""", """--exclude""", """*linux/*""", """--exclude""", """*setup/Installs/MSSQLEXP/*_x86_*.exe""", """--exclude""", """*setup/Installs/MSSQLEXP/*_x64_JPN.exe""", """--delete""")
    
        # If its not a beta, allow everyone to access it
        if ( $VersionText -ne "14beta" )
        {
            $S3Arguments += @("""--grants""", """read=uri=http://acs.amazonaws.com/groups/global/AllUsers""")
        }
        $a = [string]$S3Arguments
        cmd /c aws s3 sync  $LocalDVDImageDirectory $S3DVDImageDirectory $a | Write-Output
        if ( $LastExitCode -ne 0 ) { throw }
    } elseif ( $Cloud -eq 'Azure' ) {
        $StorageAccount = 'lansalpcmsdn'
                             
        #Save the storage account key
        $StorageKey = (Get-AzureStorageKey -StorageAccountName $StorageAccount).Primary    
        Write-Output ("$(Log-Date) Copy $LocalDVDImageDirectory directory")
        cmd /c AzCopy /Source:$LocalDVDImageDirectory            /Dest:$S3DVDImageDirectory            /DestKey:$StorageKey    /XO /Y | Write-Output
        Write-Output ("$(Log-Date) Copy $LocalDVDImageDirectory\3rdparty directory")
        cmd /c AzCopy /Source:$LocalDVDImageDirectory\3rdparty   /Dest:$S3DVDImageDirectory/3rdparty   /DestKey:$StorageKey /S /XO /Y | Write-Output
        Write-Output ("$(Log-Date) Copy $LocalDVDImageDirectory\Integrator directory")
        cmd /c AzCopy /Source:$LocalDVDImageDirectory\Integrator /Dest:$S3DVDImageDirectory/Integrator /DestKey:$StorageKey /S /XO /Y | Write-Output
        Write-Output ("$(Log-Date) Copy $LocalDVDImageDirectory\Setup directory")
        cmd /c AzCopy /Source:$LocalDVDImageDirectory\setup      /Dest:$S3DVDImageDirectory/setup      /DestKey:$StorageKey /S /XO /Y | Write-Output
        Write-Output ("$(Log-Date) Copy $LocalDVDImageDirectory\EPC directory")
        cmd /c AzCopy /Source:$LocalDVDImageDirectory\EPC        /Dest:$S3DVDImageDirectory/EPC        /DestKey:$StorageKey /S /XO /Y | Write-Output
    }

    if ( $Cloud -eq 'AWS' ) { Create-Ec2SecurityGroup }

    # First image found is presumed to be the latest image.
    # Force it into a list so that if one image is returned the variable may be used identically.

    Write-Verbose ("Locate image Name $AmazonAMIName")    

    if ( $Cloud -eq 'AWS' ) {
        $AmazonImage = @(Get-EC2Image -Filters @{Name = "name"; Values = $AmazonAMIName} | Sort-Object -Descending CreationDate)
        $ImageName = $AmazonImage[0].Name
        $Script:Imageid = $AmazonImage[0].ImageId
        Write-Output "$(Log-Date) Using Base Image $ImageName $Script:ImageId"

        Create-EC2Instance $Script:Imageid $script:keypair $script:SG
    } elseif ($Cloud -eq 'Azure' ) {
        $image=Get-AzureVMImage | where-object { $_.ImageFamily -eq $AmazonAMIName } | sort-object PublishedDate -Descending | select-object -ExpandProperty ImageName -First 1

        # If cannot find under ImageFamily, presume its a one-off LANSA image and access it by ImageName
        if ( -not $image )
        {
            $image = $AmazonAMIName
        }
        $subscription = "Visual Studio Enterprise with MSDN"
        $svcName = "bakingMSDN"
        if ($InstallIDE) {
            $vmname="BakeIDE$VersionText"
        } else {
            $vmname="Bake$VersionText"
        }
        $vmsize="Medium"
        $Script:password = "Pcxuser@122"
        $AdminUserName = "lansa"

        Write-Verbose "$(Log-Date) Delete VM if it already exists"
        Get-AzureVM -ServiceName $svcName -Name $VMName -ErrorAction SilentlyContinue | Remove-AzureVM -DeleteVHD -ErrorAction SilentlyContinue

        Write-Verbose "$(Log-Date) Create VM"
        $vm1 = New-AzureVMConfig -Name $vmname -InstanceSize $vmsize -ImageName $image
        $vm1 | Add-AzureProvisioningConfig -Windows -AdminUsername $AdminUserName -Password $Script:password
        new-azurevm -ServiceName $svcName -VMs $vm1 -WaitForBoot -Verbose

        $vm1 = Get-AzureVM -ServiceName $svcName -Name $VMName
        $Script:publicDNS = $vm1.DNSName

        # Install the WinRM Certificate first to access the VM via Remote PS
        # This REQUIRES PowerShell run Elevated
        # Also run Unblock-File .\InstallWinRMCertAzureVM.ps1 => Need to close the Powershell session before it will work.
        .$script:IncludeDir\InstallWinRMCertAzureVM.ps1 -SubscriptionName $subscription -ServiceName $svcName -Name $VMName 
 
        # Get the RemotePS/WinRM Uri to connect to
        $uri = Get-AzureWinRMUri -ServiceName $svcName -Name $VMName 
    }

    # Remote PowerShell
    $securepassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($AdminUserName, $securepassword)
    if ( $Cloud -eq 'AWS' ) {
        Connect-RemoteSession
    } elseif ($Cloud -eq 'Azure' ) {
        Connect-RemoteSessionUri
    }

    # Simple test of session: 
    # Invoke-Command -Session $Script:session {(Invoke-WebRequest http://169.254.169.254/latest/user-data).RawContent}

    Invoke-Command -Session $Script:session {Set-ExecutionPolicy Unrestricted -Scope CurrentUser}
    $remotelastexitcode = invoke-command  -Session $Script:session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -and $remotelastexitcode -ne 0 ) {
        Write-Error "LastExitCode: $remotelastexitcode"
        throw 1
    }    

    # Setup fundamental variables in remote session

    Execute-RemoteInit

    Execute-RemoteBlock $Script:session {  

        Write-Verbose ("Save S3 DVD image url and other global variables in registry")
        $lansaKey = 'HKLM:\Software\LANSA\'
        if (!(Test-Path -Path $lansaKey)) {
            New-Item -Path $lansaKey
        }
        New-ItemProperty -Path $lansaKey  -Name 'Cloud' -PropertyType String -Value $using:Cloud -Force
        New-ItemProperty -Path $lansaKey  -Name 'DVDUrl' -PropertyType String -Value $using:S3DVDImageDirectory -Force
        New-ItemProperty -Path $lansaKey  -Name 'VisualLANSAUrl' -PropertyType String -Value $using:S3VisualLANSAUpdateDirectory -Force
        New-ItemProperty -Path $lansaKey  -Name 'IntegratorUrl' -PropertyType String -Value $using:S3IntegratorUpdateDirectory -Force
        New-ItemProperty -Path $lansaKey  -Name 'GitBranch' -PropertyType String -Value $using:GitBranch -Force
        New-ItemProperty -Path $lansaKey  -Name 'VersionText' -PropertyType String -Value $using:VersionText -Force
        New-ItemProperty -Path $lansaKey  -Name 'VersionMajor' -PropertyType DWord -Value $using:VersionMajor -Force
        New-ItemProperty -Path $lansaKey  -Name 'VersionMinor' -PropertyType DWord -Value $using:VersionMinor -Force
        New-ItemProperty -Path $lansaKey  -Name 'Language' -PropertyType String -Value $using:Language -Force
        New-ItemProperty -Path $lansaKey  -Name 'InstallSQLServer' -PropertyType DWord -Value $using:InstallSQLServer -Force

        Write-Verbose "Switch off Internet download security warning"
        [Environment]::SetEnvironmentVariable('SEE_MASK_NOZONECHECKS', '1', 'Machine')

        Write-Verbose "Turn on sound from RDP sessions"
        Get-Service | Where {$_.Name -match "audio"} | format-table -autosize
        Get-Service | Where {$_.Name -match "audio"} | start-service
        Get-Service | Where {$_.Name -match "audio"} | set-service -StartupType "Automatic"

        # Ensure last exit code is 0. (exit by itself will terminate the remote session)
        cmd /c exit 0
    }

    # Load up some required tools into remote environment

    Execute-RemoteScript -Session $Script:session -FilePath "$script:IncludeDir\dot-CommonTools.ps1"

    if ( $InstallBaseSoftware ) {

        # Install Chocolatey

        Execute-RemoteScript -Session $Script:session -FilePath "$script:IncludeDir\getchoco.ps1"
    
        # Then we install git using chocolatey and pull down the rest of the files from git

        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\installGit.ps1 -ArgumentList  @($Script:GitRepo, $Script:GitRepoPath, $GitBranch, $true)

        Execute-RemoteBlock $Script:session {    "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" }

        # Load utilities into Remote Session.
        # Requires the git repo to be pulled down so the scripts are present and the script variables initialised with Init-Baking-Vars.ps1.
        # Reflect local variables into remote session
        Execute-RemoteInitPostGit

        # Upload files that are not in Git. Should be limited to secure files that must not be in Git.
        # Git is a far faster mechansim for transferring files than using RemotePS.
        # From now on we may execute scripts which rely on other scripts to be present from the LANSA Cookbooks git repo

        #####################################################################################
        Write-Output "$(Log-Date) Installing License"
        #####################################################################################

        Send-RemotingFile $Script:session "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx" "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx"
        Execute-RemoteBlock $Script:session {CreateLicence "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx" $Using:LicenseKeyPassword "LANSA Development License" "DevelopmentLicensePrivateKey" }

        #####################################################################################

        Write-Output "$(Log-Date) workaround which must be done before Chef is installed when SQL Server is not already installed. Has to be run through RDP too!"
        MessageBox "Run install-base-sql-server.ps1. Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"

        #####################################################################################
        Write-Output "$(Log-Date) Installing base software"
        #####################################################################################

        if ( $Cloud -eq 'AWS' ) {
            $ChefRecipe = "VLWebServer::IDEBase"
        } elseif ($Cloud -eq 'Azure' ) {
            $ChefRecipe = "VLWebServer::IDEBaseAzure"
        }

        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-base.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath, $script:licensekeypassword, $ChefRecipe )

        if ( $InstallSQLServer ) {
            #####################################################################################
            Write-Output "$(Log-Date) Install SQL Server. (Remote execution does not work)"
            #####################################################################################
            MessageBox "Run install-sql-server.ps1. Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"
        }

        #####################################################################################
        Write-Output "$(Log-Date) Rebooting to ensure the newly installed DesktopExperience feature is ready to have Windows Updates run"
        #####################################################################################
        Execute-RemoteBlock $Script:session {  
		    Write-Output "$(Log-Date) Restart Required - Restarting..."
		    Restart-Computer -Force
    
            # Ensure last exit code is 0. (exit by itself will terminate the remote session)
            cmd /c exit 0
        }
    } else {
        Execute-RemoteBlock $Script:session {
            Write-Verbose "$(Log-Date) Refreshing git tools repo"
            cd $using:GitRepoPath
            cmd /c git reset --hard HEAD '2>&1'
            cmd /c git pull '2>&1'
            cmd /c exit 0
        }
    }


    MessageBox "Run Windows Updates. Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. Keep running Windows Updates until it displays the message 'Done Installing Windows Updates. Restart not required'. Now click OK on this message box"

    # Session has probably been lost due to a Windows Updates reboot
    if ( -not $Script:session -or ($Script:session.State -ne 'Opened') )
    {
        Write-Output "$(Log-Date) Session lost or not open. Reconnecting..."
        if ( $Script:session ) { Remove-PSSession $Script:session }

        if ( $Cloud -eq 'AWS' ) {
            Connect-RemoteSession
        } elseif ($Cloud -eq 'Azure' ) {
            Connect-RemoteSessionUri
        }

        Execute-RemoteInit
        Execute-RemoteInitPostGit
    }

    if ( $InstallIDE -eq $true ) {

        Write-Output "$(Log-Date) Installing IDE"
        PlaySound

        MessageBox "Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"
        MessageBox "Check SQL Server is running in VM, then click OK on this message box"
        MessageBox "Run install-lansa-ide.ps1 in a NEW Powershell ISE session. When complete, click OK on this message box"

        # Fixed? => Cannot install IDE remotely at the moment becasue it requires user input on the remote session and its not possible to log in to that session
        # Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-ide.ps1

        MessageBox "Have you re-sized the Internet Explorer window? SIZE it, don't MAXIMIZE it, so that all of the StartHere document can be read."

        MessageBox "Install patches. Then click OK on this message box"
    } else {
        # Scalable image comes through here
        if ( $InstallSQLServer -eq $false ) {
            Write-Output "$(Log-Date) workaround for sysprep failing unless admin has logged in!"
            MessageBox "Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password' and then click OK on this message box. (Yes, do nothing else. Just log in!)"
        }
    }

    Write-Output "$(Log-Date) Completing installation steps, except for sysprep"
    Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-post-winupdates.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath )

    if ( $InstallIDE -or ($InstallSQLServer -eq -$false) ) {
        Invoke-Command -Session $Script:session {
            Write-Verbose "$(Log-Date) Switch Internet download security warning back on"
            [Environment]::SetEnvironmentVariable('SEE_MASK_NOZONECHECKS', '0', 'Machine')
            Set-ExecutionPolicy restricted -Scope CurrentUser
        }
    }

    Write-Output "$(Log-Date) Sysprep"
    Write-Verbose "Use Invoke-Command as the Sysprep will terminate the instance and thus Execute-RemoteBlock will return a fatal error"
    if ( $Cloud -eq 'AWS' ) {
        Invoke-Command -Session $Script:session {cmd /c "$ENV:ProgramFiles\Amazon\Ec2ConfigService\ec2config.exe" -sysprep}
    } elseif ($Cloud -eq 'Azure' ) {
        Invoke-Command -Session $Script:session {cd "$env:SystemRoot\system32\sysprep"}
        Invoke-Command -Session $Script:session {cmd /c sysprep /oobe /generalize /shutdown}
    }

    Remove-PSSession $Script:session

    # Sysprep will stop the Instance

    if ( $Cloud -eq 'Azure' ) {
        Wait-AzureVMState $svcName $vmname "StoppedVM"

        Write-Output "$(Log-Date) Creating Azure Image"
    
        Write-Verbose "$(Log-Date) Delete image if it already exists"
        Get-AzureVMImage -ImageName "$($vmname)image" -ErrorAction SilentlyContinue | Remove-AzureVMImage -DeleteVHD -ErrorAction SilentlyContinue
        Save-AzureVMImage -ServiceName $svcName -Name $vmname -ImageName "$($VersionText)image" -OSState Generalized

    } elseif ($Cloud -eq 'AWS') {
        # Wait for the instance state to be stopped.

        Wait-EC2State $instanceid "Stopped"

        Write-Output "$(Log-Date) Creating AMI"

        $TagDesc = "$($AmazonImage[0].Description) created on $($AmazonImage[0].CreationDate) with LANSA IDE $VersionText installed on $(Log-Date)"
        $AmiName = "$Script:DialogTitle $VersionText $(Get-Date -format "yyyy-MM-ddTHH-mm-ss")"     # AMI ID must not contain colons
        $amiID = New-EC2Image -InstanceId $Script:instanceid -Name $amiName -Description $TagDesc
 
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
  
        # Add tags to snapshots associated with the AMI using Amazon.EC2.Model.EbsBlockDevice

        $amiBlockDeviceMapping = $amiProperties.BlockDeviceMapping # Get Amazon.Ec2.Model.BlockDeviceMapping
        $amiBlockDeviceMapping.ebs | `
        ForEach-Object -Process {
            if ( $_ -and $_.SnapshotID )
            {
                New-EC2Tag -Resources $_.SnapshotID -Tags @( @{ Key = "Name" ; Value = $tagName}, @{ Key = "Description"; Value = $tagDesc } )
            }
        } 
    }    

    PlaySound

    if ($Cloud -eq 'AWS') {
        #####################################################################################
        Write-Output ("Delete Security Group. Should work first time, provided its not being used by an EC2 instance, but just in case, try it in a loop")
        #####################################################################################

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
                $_
                $err = $true
                Write-Output "$(Log-Date) Waiting for Security Group to be deleted"
                Sleep -Seconds 10
            }
        }
    }
}
catch
{
    Write-Error ($_ | format-list | out-string)
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
