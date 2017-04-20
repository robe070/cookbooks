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
    $InstallScalable=$false,

    [Parameter(Mandatory=$false)]
    [boolean]
    $InstallBaseSoftware=$true,

    [Parameter(Mandatory=$false)]
    [string]
    $Cloud='AWS',

    [Parameter(Mandatory=$false)]
    [boolean]
    $Win2012=$true,

    [Parameter(Mandatory=$false)]
    [boolean]
    $SkipSlowStuff=$false,

    [Parameter(Mandatory=$false)]
    [boolean]
    $Upgrade=$false
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

    Write-Output ("$(Log-Date) Allow Remote Powershell session to any host. If it fails you are not runniong as Administrator!")
    set-item wsman:\localhost\Client\TrustedHosts -value * -force

    if ( $Win2012 -eq $true ) {
        $Platform = 'Win2012'
    } else {
        $Platform = 'Win2016'
    }

    if ( !$SkipSlowStuff ) {
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
            [String[]] $S3Arguments = @("--exclude", "*ibmi/*", "--exclude", "*AS400/*", "--exclude", "*linux/*", "--exclude", "*setup/Installs/MSSQLEXP/*_x86_*.exe", "--exclude", "*setup/Installs/MSSQLEXP/*_x64_JPN.exe", "--delete")
    
            # If its not a beta, allow everyone to access it
            if ( $VersionText -ne "14beta" )
            {
                $S3Arguments += @("--grants", "read=uri=http://acs.amazonaws.com/groups/global/AllUsers")
            }
            cmd /c aws s3 sync  $LocalDVDImageDirectory $S3DVDImageDirectory $S3Arguments | Write-Output
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

            if ( (Test-Path -Path $LocalDVDImageDirectory\EPC) ) {
                Write-Output ("$(Log-Date) Copy $LocalDVDImageDirectory\EPC directory")
                cmd /c AzCopy /Source:$LocalDVDImageDirectory\EPC    /Dest:$S3DVDImageDirectory/EPC        /DestKey:$StorageKey /S /XO /Y | Write-Output
            }
        }
    }

    if ( $Cloud -eq 'AWS' ) { Create-Ec2SecurityGroup }

    # First image found is presumed to be the latest image.
    # Force it into a list so that if one image is returned the variable may be used identically.

    Write-Verbose ("Locate image Name $AmazonAMIName")    


    if ( $Cloud -eq 'AWS' ) {
        $AdminUserName = "administrator"
        $AmazonImage = @(Get-EC2Image -Filters @{Name = "name"; Values = $AmazonAMIName} | Sort-Object -Descending CreationDate)
        $ImageName = $AmazonImage[0].Name
        $Script:Imageid = $AmazonImage[0].ImageId
        Write-Output "$(Log-Date) Using Base Image $ImageName $Script:ImageId"

        Create-EC2Instance $Script:Imageid $script:keypair $script:SG

        $vmname="Bake $Script:instancename"

    } elseif ($Cloud -eq 'Azure' ) {
        $image=Get-AzureVMImage | where-object { $_.Label -like "$AmazonAMIName" } | sort-object PublishedDate -Descending | select-object -ExpandProperty ImageName -First 1

        # If cannot find under ImageFamily, presume its a one-off LANSA image and access it by ImageName
        if ( -not $image )
        {
            $image = $AmazonAMIName
        }
        $subscription = "Visual Studio Enterprise with MSDN"
        $svcName = "bakingMSDN"
        $vmsize="Medium"
        $Script:password = "Pcxuser@122"
        $AdminUserName = "lansa"
        $vmname = $VersionText

        Write-Verbose "$(Log-Date) Delete VM if it already exists"
        Get-AzureVM -ServiceName $svcName -Name $VMName -ErrorAction SilentlyContinue | Remove-AzureVM -DeleteVHD -ErrorAction SilentlyContinue

        Write-Verbose "$(Log-Date) Create VM"
        $vm1 = New-AzureVMConfig -Name $vmname -InstanceSize $vmsize -ImageName $image
        $vm1 | Add-AzureProvisioningConfig -Windows -AdminUsername $AdminUserName -Password $Script:password -DisableGuestAgent
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

        if ( !$using:Upgrade ) {
            Write-Verbose "Turn on sound from RDP sessions"
            Get-Service | Where {$_.Name -match "audio"} | format-table -autosize
            Get-Service | Where {$_.Name -match "audio"} | start-service
            Get-Service | Where {$_.Name -match "audio"} | set-service -StartupType "Automatic"
        }
        # Ensure last exit code is 0. (exit by itself will terminate the remote session)
        cmd /c exit 0
    }

    # Load up some required tools into remote environment

    Execute-RemoteScript -Session $Script:session -FilePath "$script:IncludeDir\dot-CommonTools.ps1"

    if ( $InstallBaseSoftware ) {

        # Install Chocolatey

        Execute-RemoteScript -Session $Script:session -FilePath "$script:IncludeDir\getchoco.ps1"
    
        # Then we install git using chocolatey and pull down the rest of the files from git

        # Load basic utils before running git script
        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\dot-CommonTools.ps1
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

        if ( $Cloud -eq 'AWS' ) {
            Run-SSMCommand -InstanceId @($instanceid) -DocumentName AWS-RunPowerShellScript -Comment 'Installing workarounds' -Parameter @{'commands'=@("c:\lansa\scripts\install-base-sql-server.ps1")}
        } else {
            Write-Output "$(Log-Date) workaround which must be done before Chef is installed. Has to be run through RDP too!"
            Write-Output "$(Log-Date) also, workaround for x_err.log 'Code=800703fa. Code meaning=Illegal operation attempted on a registry key that has been marked for deletion.' Application Event Log warning 1530 "
            MessageBox "Run install-base-sql-server.ps1. Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"
        }


        #####################################################################################
        Write-Output "$(Log-Date) Installing base software"
        #####################################################################################

        if ( $Cloud -eq 'AWS' ) {
            $ChefRecipe = "VLWebServer::IDEBase"
        } elseif ($Cloud -eq 'Azure' ) {
            $ChefRecipe = "VLWebServer::IDEBaseAzure"
        }

        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-base.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath, $script:licensekeypassword, $ChefRecipe )
    } else {
        Execute-RemoteBlock $Script:session {
            Write-Verbose "$(Log-Date) Refreshing git tools repo"
            # Ensure we cope with an existing repo, not just a new clone...
            cd $using:GitRepoPath
            # Throw away any working directory changes
            cmd /c git reset --hard HEAD '2>&1'
            # Ensure we have all changes
            cmd /c git fetch --all '2>&1'
            # Check out a potentially different branch
            Write-Output "Branch: $using:GitBranch"
            cmd /c git checkout -f $using:GitBranch  '2>&1'
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) 
            {
                Write-Error ('Git checkout failed');
                cmd /c exit $LastExitCode;
            }
            # Finally make sure the current branch matches the origin
            cmd /c git pull '2>&1'
        }
    }

    if ( $InstallSQLServer ) {
        #####################################################################################
        Write-Output "$(Log-Date) Install SQL Server. (Remote execution does not work)"
        #####################################################################################
        MessageBox "Run install-sql-server.ps1. Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"

        #####################################################################################
        Write-Output "$(Log-Date) Rebooting to ensure the newly installed DesktopExperience feature is ready to have Windows Updates run"
        #####################################################################################
        Execute-RemoteBlock $Script:session {  
		    Write-Output "$(Log-Date) Restart Required - Restarting..."
		    Restart-Computer -Force
    
            # Ensure last exit code is 0. (exit by itself will terminate the remote session)
            cmd /c exit 0
        }

        # Session has been lost due to a Windows reboot
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
    }

    # No harm installing this again if its already installed    
    if ( $InstallIDE -eq $true) {
        if ( $Win2012 ) {
            Write-Verbose "$(Log-Date) Run choco install jdk8 -y. No idea why it fails to run remotely!"
            if ( $Cloud -eq 'AWS' ) {
                Run-SSMCommand -InstanceId @($instanceid) -DocumentName AWS-RunPowerShellScript -Comment 'Installing JDK' -Parameter @{'commands'=@("choco install jdk8 -y")}
            } else {
                MessageBox "Run choco install jdk8 -y manually. Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"
            }
        } else {
            Execute-RemoteBlock $Script:session { Run-ExitCode 'choco' @('install', 'jdk8', '-y') }
        }
    }

    if ( !$SkipSlowStuff ) {
        if ( $Cloud -eq 'AWS' ) {
            # Windows Updates can take quite a while to run if there are multiple re-boots, so set timeout to 1 hour
            Run-SSMCommand -InstanceId $instanceid -DocumentName AWS-InstallWindowsUpdates -TimeoutSecond 3600 -Sleep 10 -Comment 'Run Windows Updates' -Parameter @{'Action'='Install'}
            Write-Host "$(Log-Date) Windows Updates complete"
        } else {
            MessageBox "Run Windows Updates. Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. Keep running Windows Updates until it displays the message 'Done Installing Windows Updates. Restart not required'. Now click OK on this message box"
        }
    }

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

        #####################################################################################
        Write-Output "$(Log-Date) Installing License"
        #####################################################################################

        Send-RemotingFile $Script:session "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx" "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx"
        Execute-RemoteBlock $Script:session {CreateLicence "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx" $Using:LicenseKeyPassword "LANSA Development License" "DevelopmentLicensePrivateKey" }

        Write-Output "$(Log-Date) Installing IDE"
        PlaySound

        if ( $Cloud -eq 'AWS' ) {
            # Run-SSMCommand -InstanceId @($instanceid) -DocumentName AWS-RunPowerShellScript -Comment 'Installing LANSA IDE' -Parameter @{'commands'=@("c:\lansa\scripts\install-lansa-ide.ps1")}
            Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-ide.ps1
        } else {

            MessageBox "Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"
            MessageBox "Check SQL Server is running in VM, then click OK on this message box"
            MessageBox "Run install-lansa-ide.ps1 in a NEW Powershell ISE session. When complete, click OK on this message box"
        }
    }

    if ( $InstallScalable -eq $true ) {
        Send-RemotingFile $Script:session "$Script:LicenseKeyPath\LANSAScalableLicense.pfx" "$Script:LicenseKeyPath\LANSAScalableLicense.pfx"
        Send-RemotingFile $Script:session "$Script:LicenseKeyPath\LANSAIntegratorLicense.pfx" "$Script:LicenseKeyPath\LANSAIntegratorLicense.pfx"

        # Must run install-lansa-scalable.ps1 after Windows Updates as it sets RunOnce after which you must not reboot.
        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-scalable.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath, $script:licensekeypassword)

        Write-Output "$(Log-Date) workaround for sysprep failing unless admin has logged in!"
        MessageBox "Please RDP into $vmname $Script:publicDNS as $AdminUserName using password '$Script:password' and then click OK on this message box. (Yes, do nothing else. Just log in!)"
    }

    # Check if Session has been lost due to a Windows reboot
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

    Write-Host "$(Log-Date) Completing installation steps, except for sysprep"
    Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-post-winupdates.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath )

    if ( $InstallIDE -or ($InstallSQLServer -eq -$false) ) {
        Invoke-Command -Session $Script:session {
            Write-Verbose "$(Log-Date) Switch Internet download security warning back on"
            [Environment]::SetEnvironmentVariable('SEE_MASK_NOZONECHECKS', '0', 'Machine')
            # Set-ExecutionPolicy restricted -Scope CurrentUser
        }
    }

    Write-Host "$(Log-Date) Sysprep"
    Write-Verbose "Use Invoke-Command as the Sysprep will terminate the instance and thus Execute-RemoteBlock will return a fatal error"
    if ( $Cloud -eq 'AWS' ) {
        if ( $Win2012 ) {
            Invoke-Command -Session $Script:session {cmd /c "$ENV:ProgramFiles\Amazon\Ec2ConfigService\ec2config.exe" -sysprep}
        } else {
            # See here for doco - http://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch.html
            Invoke-Command -Session $Script:session {cd $ENV:ProgramData\Amazon\EC2-Windows\Launch\Scripts}
            Invoke-Command -Session $Script:session {./InitializeInstance.ps1 -Schedule}
            Invoke-Command -Session $Script:session {./SysprepInstance.ps1}
        }
    } elseif ($Cloud -eq 'Azure' ) {
        MessageBox "Run sysprep manually because it fails remotely!. When complete, click OK on this message box"

        # Invoke-Command -Session $Script:session {cd "$env:SystemRoot\system32\sysprep"}
        # Invoke-Command -Session $Script:session {cmd /c sysprep /oobe /generalize /shutdown}
    }

    Remove-PSSession $Script:session

    # Sysprep will stop the Instance

    if ( $Cloud -eq 'Azure' ) {
        Wait-AzureVMState $svcName $vmname "StoppedVM"

        Write-Host "$(Log-Date) Creating Azure Image"
    
        Write-Verbose "$(Log-Date) Delete image if it already exists"
        $ImageName = "$($VersionText)image"
        Get-AzureVMImage -ImageName $ImageName -ErrorAction SilentlyContinue | Remove-AzureVMImage -DeleteVHD -ErrorAction SilentlyContinue
        Save-AzureVMImage -ServiceName $svcName -Name $vmname -ImageName $ImageName -OSState Generalized

        Write-Host "$(Log-Date) Obtaining signed url for submission to Azure Marketplace"
        .$script:IncludeDir\get-azure-sas-token.ps1 -ImageName $ImageName

    } elseif ($Cloud -eq 'AWS') {
        # Wait for the instance state to be stopped.

        Wait-EC2State $instanceid "Stopped"

        Write-Host "$(Log-Date) Creating AMI"

        $TagDesc = "$($AmazonImage[0].Description) created on $($AmazonImage[0].CreationDate) with LANSA IDE $VersionText installed on $(Log-Date)"
        $AmiName = "$Script:DialogTitle $VersionText $(Get-Date -format "yyyy-MM-ddTHH-mm-ss") $Platform"     # AMI ID must not contain colons
        $amiID = New-EC2Image -InstanceId $Script:instanceid -Name $amiName -Description $TagDesc
 
        $tagName = $amiName # String for use with the name TAG -- as opposed to the AMI name, which is something else and set in New-EC2Image
 
        New-EC2Tag -Resources $amiID -Tags @{ Key = "Name" ; Value = $amiName} # Add tags to new AMI
    
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
        Write-Host "$(Log-Date) AMI is available"
  
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
