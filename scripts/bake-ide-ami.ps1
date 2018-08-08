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
    $ManualWinUpd=$false,

    [Parameter(Mandatory=$false)]
    [boolean]
    $SkipSlowStuff=$false,

    [Parameter(Mandatory=$false)]
    [boolean]
    $Upgrade=$false
    )

    #Requires -RunAsAdministrator
    
# set up environment if not yet setup
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Host "$(Log-Date) Environment already initialised"
}

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

if ($InstallIDE -eq $true) {
    $Script:DialogTitle = "LANSA IDE"
    $script:instancename = "LANSA IDE $VersionText installed on $(Log-Date)"
}


if ($InstallScalable -eq $true) {
    $Script:DialogTitle = "LANSA Scalable License "
    $script:instancename = "LANSA Scalable License $VersionText installed on $(Log-Date)"
}

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

    if ( $Win2012 -eq $true ) {
        $Platform = 'Win2012'
    } else {
        $Platform = 'Win2016'
    }

    if ( !$SkipSlowStuff -and !$InstallScalable ) {
        Write-Host ("$(Log-Date) Upload any changes to current installation image")

        Write-Verbose ("Test if source of DVD image exists") | Out-Host
        if ( !(Test-Path -Path $LocalDVDImageDirectory) )
        {
            throw "LocalDVDImageDirectory '$LocalDVDImageDirectory' does not exist."
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
            cmd /c aws s3 sync  $LocalDVDImageDirectory $S3DVDImageDirectory $S3Arguments | Write-Host
            if ( $LastExitCode -ne 0 ) { throw }
        } elseif ( $Cloud -eq 'Azure' ) {
            $StorageAccount = 'lansalpcmsdn'
                             
            #Save the storage account key
            $StorageKey = (Get-AzureStorageKey -StorageAccountName $StorageAccount).Primary    
            Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory directory")
            cmd /c AzCopy /Source:$LocalDVDImageDirectory            /Dest:$S3DVDImageDirectory            /DestKey:$StorageKey    /XO /Y | Write-Host
            Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\3rdparty directory")
            cmd /c AzCopy /Source:$LocalDVDImageDirectory\3rdparty   /Dest:$S3DVDImageDirectory/3rdparty   /DestKey:$StorageKey /S /XO /Y | Write-Host
            Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\Integrator directory")
            cmd /c AzCopy /Source:$LocalDVDImageDirectory\Integrator /Dest:$S3DVDImageDirectory/Integrator /DestKey:$StorageKey /S /XO /Y | Write-Host
            Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\Setup directory")
            cmd /c AzCopy /Source:$LocalDVDImageDirectory\setup      /Dest:$S3DVDImageDirectory/setup      /DestKey:$StorageKey /S /XO /Y | Write-Host

            if ( (Test-Path -Path $LocalDVDImageDirectory\EPC) ) {
                Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\EPC directory")
                cmd /c AzCopy /Source:$LocalDVDImageDirectory\EPC    /Dest:$S3DVDImageDirectory/EPC        /DestKey:$StorageKey /S /XO /Y | Write-Host
            }
        }
    }

    if ( $Cloud -eq 'AWS' ) { Create-Ec2SecurityGroup }

    # First image found is presumed to be the latest image.
    # Force it into a list so that if one image is returned the variable may be used identically.

    Write-Verbose ("Locate image Name $AmazonAMIName") | Out-Host

    if ( $Cloud -eq 'AWS' ) {
        $AdminUserName = "administrator"
        $AmazonImage = @(Get-EC2Image -Filters @{Name = "name"; Values = $AmazonAMIName} | Sort-Object -Descending CreationDate)
        $ImageName = $AmazonImage[0].Name
        $Script:Imageid = $AmazonImage[0].ImageId
        Write-Host "$(Log-Date) Using Base Image $ImageName $Script:ImageId"

        Create-EC2Instance $Script:Imageid $script:keypair $script:SG -InstanceType 't2.large'

        $Script:vmname="Bake $Script:instancename"

    } elseif ($Cloud -eq 'Azure' ) {
        $imageObj=@(Get-AzureVMImage | where-object { $_.Label -like "$AmazonAMIName" } | sort-object PublishedDate -Descending)
        if ( $imageObj ) {
            $imageObj[0]
            $image=$imageObj[0].ImageName
        }

        # If cannot find under Label, presume its a one-off LANSA image and access it as if the supplied name is an ImageName
        if ( -not $image )
        {
            $image = $AmazonAMIName
        }
        $subscription = "Visual Studio Enterprise with MSDN"
        $svcName = "bakingMSDN"
        $vmsize="Medium"
        $Script:password = "Pcxuser@122"
        $AdminUserName = "lansa"
        $Script:vmname = $VersionText

        Write-Verbose "$(Log-Date) Delete VM if it already exists" | Out-Host
        Get-AzureVM -ServiceName $svcName -Name $Script:vmname -ErrorAction SilentlyContinue | Remove-AzureVM -DeleteVHD -ErrorAction SilentlyContinue

        Write-Verbose "$(Log-Date) Create VM" | Out-Host
        $vm1 = New-AzureVMConfig -Name $Script:vmname -InstanceSize $vmsize -ImageName $image
        $vm1 | Add-AzureProvisioningConfig -Windows -AdminUsername $AdminUserName -Password $Script:password -DisableGuestAgent
        new-azurevm -ServiceName $svcName -VMs $vm1 -WaitForBoot -Verbose

        $vm1 = Get-AzureVM -ServiceName $svcName -Name $Script:vmname
        $Script:publicDNS = $vm1.DNSName

        # Install the WinRM Certificate first to access the VM via Remote PS
        # This REQUIRES PowerShell run Elevated
        # Also run Unblock-File .\InstallWinRMCertAzureVM.ps1 => Need to close the Powershell session before it will work.
        .$script:IncludeDir\InstallWinRMCertAzureVM.ps1 -SubscriptionName $subscription -ServiceName $svcName -Name $Script:vmname 
 
        # Get the RemotePS/WinRM Uri to connect to
        $uri = Get-AzureWinRMUri -ServiceName $svcName -Name $Script:vmname 
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
        try {
            Write-Verbose ("Save S3 DVD image url and other global variables in registry") | Out-Host
            $lansaKey = 'HKLM:\Software\LANSA\'
            if (!(Test-Path -Path $lansaKey)) {
                New-Item -Path $lansaKey | Out-Host
            }
            New-ItemProperty -Path $lansaKey  -Name 'Cloud' -PropertyType String -Value $using:Cloud -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'DVDUrl' -PropertyType String -Value $using:S3DVDImageDirectory -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'VisualLANSAUrl' -PropertyType String -Value $using:S3VisualLANSAUpdateDirectory -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'IntegratorUrl' -PropertyType String -Value $using:S3IntegratorUpdateDirectory -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'GitBranch' -PropertyType String -Value $using:GitBranch -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'VersionText' -PropertyType String -Value $using:VersionText -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'VersionMajor' -PropertyType DWord -Value $using:VersionMajor -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'VersionMinor' -PropertyType DWord -Value $using:VersionMinor -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'Language' -PropertyType String -Value $using:Language -Force | Out-Host
            New-ItemProperty -Path $lansaKey  -Name 'InstallSQLServer' -PropertyType DWord -Value $using:InstallSQLServer -Force | Out-Host

            Write-Verbose "Switch off Internet download security warning" | Out-Host
            [Environment]::SetEnvironmentVariable('SEE_MASK_NOZONECHECKS', '1', 'Machine') | Out-Host

            if ( !$using:Upgrade ) {
                Write-Verbose "Turn on sound from RDP sessions" | Out-Host
                Get-Service | Where {$_.Name -match "audio"} | format-table -autosize | Out-Host
                Get-Service | Where {$_.Name -match "audio"} | start-service | Out-Host
                Get-Service | Where {$_.Name -match "audio"} | set-service -StartupType "Automatic" | Out-Host
            }
        } catch {
            Write-RedOutput $_ | Out-Host
            Write-RedOutput $PSItem.ScriptStackTrace | Out-Host
            throw 'Script Block 10'
        }
        # Ensure last exit code is 0. (exit by itself will terminate the remote session)
        cmd /c exit 0
    }

    # Load up some required tools into remote environment

    # Load basic utils before running anything
    Execute-RemoteScript -Session $Script:session -FilePath "$script:IncludeDir\dot-CommonTools.ps1"

    if ( $InstallBaseSoftware ) {

        # Install Chocolatey

        Execute-RemoteScript -Session $Script:session -FilePath "$script:IncludeDir\getchoco.ps1"
    
        # Then we install git using chocolatey and pull down the rest of the files from git

        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\installGit.ps1 -ArgumentList  @($Script:GitRepo, $Script:GitRepoPath, $GitBranch, $true)

        Execute-RemoteBlock $Script:session { "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host }

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
            Write-Host "$(Log-Date) workaround which must be done before Chef is installed. Has to be run through RDP too!"
            Write-Host "$(Log-Date) also, workaround for x_err.log 'Code=800703fa. Code meaning=Illegal operation attempted on a registry key that has been marked for deletion.' Application Event Log warning 1530 "
            $dummy = MessageBox "Run install-base-sql-server.ps1. Please RDP into $Script:vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"
        }


        #####################################################################################
        Write-Host "$(Log-Date) Installing base software"
        #####################################################################################

        if ( $Cloud -eq 'AWS' ) {
            $ChefRecipe = "VLWebServer::IDEBase"
        } elseif ($Cloud -eq 'Azure' ) {
            $ChefRecipe = "VLWebServer::IDEBaseAzure"
        }

        # Make sure the session is initialised correctly
        ReConnect-Session

        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-base.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath, $script:licensekeypassword, $ChefRecipe )
    } else {
        Execute-RemoteInitPostGit

        Execute-RemoteBlock $Script:session {
            Write-Verbose "$(Log-Date) Refreshing git tools repo" | Out-Host
            # Ensure we cope with an existing repo, not just a new clone...
            cd $using:GitRepoPath
            # Throw away any working directory changes
            cmd /c git reset --hard HEAD '2>&1'
            # Ensure we have all changes
            cmd /c git fetch --all '2>&1'
            # Check out a potentially different branch
            Write-Host "Branch: $using:GitBranch"
            # Check out ORIGINs correct branch so we can then FORCE checkout of potentially an existing, but rebased branch
            cmd /c git checkout "origin/$using:GitBranch"  '2>&1'
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) 
            {
                throw 'Git checkout failed'
            }
            # Overwrite the origin's current tree onto the branch we really want - the local branch
            cmd /c git checkout -B $using:GitBranch  '2>&1'
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) 
            {
                throw 'Git checkout failed'
            }
        }
    }

    ReConnect-Session

    if ( $InstallSQLServer ) {
        #####################################################################################
        Write-Host "$(Log-Date) Install SQL Server. (Remote execution does not work)"
        #####################################################################################
        $dummy = MessageBox "Run install-sql-server.ps1. Please RDP into $Script:vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"

        #####################################################################################
        Write-Host "$(Log-Date) Rebooting to ensure the newly installed DesktopExperience feature is ready to have Windows Updates run"
        #####################################################################################
        Execute-RemoteBlock $Script:session {  
		    Write-Host "$(Log-Date) Restart Required - Restarting..."
		    Restart-Computer -Force
    
            # Ensure last exit code is 0. (exit by itself will terminate the remote session)
            cmd /c exit 0
        }

        # Session has been lost due to a Windows reboot
        if ( -not $Script:session -or ($Script:session.State -ne 'Opened') )
        {
            Write-Host "$(Log-Date) Session lost or not open. Reconnecting..."
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

    ReConnect-Session

    # No harm installing this again if its already installed    
    if ( $InstallIDE -eq $true) {
        if ( $Win2012 ) {
            Write-Verbose "$(Log-Date) Run choco install jdk8 -y. No idea why it fails to run remotely!" | Out-Host
            Write-Verbose "$(Log-Date) Maybe due to jre8 404? Give it a go when next build IDE" | Out-Host
            
            if ( $Cloud -eq 'AWS' ) {
                Run-SSMCommand -InstanceId @($instanceid) -DocumentName AWS-RunPowerShellScript -Comment 'Installing JDK' -Parameter @{'commands'=@("choco install jdk8 -y")}
            } else {
                $dummy = MessageBox "Try changing this to automatically running Windows Updates in Azure? (now that we re-create the session for each script)"
                $dummy = MessageBox "Run choco install jdk8 -y manually. Please RDP into $Script:vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. When complete, click OK on this message box"
            }
        } else {
            Execute-RemoteBlock $Script:session { 
                Run-ExitCode 'choco' @('install', 'jdk8', '-y', '--no-progress') 
            }
        }
    }

    if ( !$SkipSlowStuff ) {
        if ( $Cloud -eq 'AWS' ) {
            # Windows Updates can take quite a while to run if there are multiple re-boots, so set timeout to 1 hour
            Run-SSMCommand -InstanceId $instanceid -DocumentName AWS-InstallWindowsUpdates -TimeoutSecond 3600 -Sleep 10 -Comment 'Run Windows Updates' -Parameter @{'Action'='Install'}
            Write-Host "$(Log-Date) Windows Updates complete"
        } else {
            $dummy = MessageBox "Try changing this to automatically running Windows Updates in Azure? (now that we re-create the session for each script)"
            $dummy = MessageBox "Run Windows Updates. Please RDP into $Script:vmname $Script:publicDNS as $AdminUserName using password '$Script:password'. Keep running Windows Updates until it displays the message 'Done Installing Windows Updates. Restart not required'. Now click OK on this message box"
        }
    }

    if ( $ManualWinUpd ) {
        $dummy = MessageBox "Manually install Windows updates"
    }

    ReConnect-Session

    if ( $InstallIDE -eq $true ) {

        #####################################################################################
        Write-Host "$(Log-Date) Installing License"
        #####################################################################################

        Send-RemotingFile $Script:session "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx" "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx"
        Execute-RemoteBlock $Script:session {
            CreateLicence "$Script:LicenseKeyPath\LANSADevelopmentLicense.pfx" $Using:LicenseKeyPassword "LANSA Development License" "DevelopmentLicensePrivateKey" 
            # Errors are thrown out of CreateLicense so no need to catch a throw here.
            # Let the local script catch it
        }

        Execute-RemoteBlock $Script:session {  
            try {
                Test-RegKeyValueIsNotNull 'DevelopmentLicensePrivateKey'
            } catch {
                Write-RedOutput "Test-RegKeyValueIsNotNull script block in bake-ide-ami.ps1 is the <No file> in the stack dump below" | Out-Host
                Write-RedOutput $_ | Out-Host
                Write-RedOutput $PSItem.ScriptStackTrace | Out-Host
                cmd /c exit 1
                throw              
            }
        }

        Write-Host "$(Log-Date) Installing IDE"
        PlaySound


        if ( $Upgrade -eq $false ) {
            Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-ide.ps1
        } else {
            # Need to pass a single parameter (UPGD) which seems to be extremely complicated when you have the script in a file like we have here.
            # So the simple solution is to use a script block which means the path to the script provided here is relative to the REMOTE system 
            Invoke-Command -Session $Script:session {
                $lastexitcode = 0

                c:\lansa\scripts\install-lansa-ide.ps1 -UPGD 'true' -Wait 'false'
            } -ArgumentList 'true'
                    
            $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
            if ( $remotelastexitcode -and $remotelastexitcode -ne 0 ) {
                Write-Error "LastExitCode: $remotelastexitcode"
                throw 1
            }      
        }
    }

    if ( $InstallScalable -eq $true ) {
        Send-RemotingFile $Script:session "$Script:LicenseKeyPath\LANSAScalableLicense.pfx" "$Script:LicenseKeyPath\LANSAScalableLicense.pfx" | Out-Host
        Send-RemotingFile $Script:session "$Script:LicenseKeyPath\LANSAIntegratorLicense.pfx" "$Script:LicenseKeyPath\LANSAIntegratorLicense.pfx" | Out-Host

        # Must run install-lansa-scalable.ps1 after Windows Updates as it sets RunOnce after which you must not reboot.
        Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-scalable.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath, $script:licensekeypassword)

        Write-Host "Test that keys are configured"

        Execute-RemoteBlock $Script:session {  
            try {
                Test-RegKeyValueIsNotNull 'ScalableLicensePrivateKey'
                Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'
            } catch {
                Write-RedOutput "Test-RegKeyValueIsNotNull script block in bake-ide-ami.ps1 is the <No file> in the stack dump below" | Out-Host
                Write-RedOutput $_ | Out-Host
                Write-RedOutput $PSItem.ScriptStackTrace | Out-Host
                cmd /c exit 1
                throw              
            }
         }
    }

    # Re-create Session which may have been lost due to a Windows reboot, and do it anyway so its a clean session with output working
    ReConnect-Session

    Write-Host "$(Log-Date) Completing installation steps, except for sysprep"
    Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\install-lansa-post-winupdates.ps1 -ArgumentList  @($Script:GitRepoPath, $Script:LicenseKeyPath )

    if ( $InstallIDE -or ($InstallSQLServer -eq -$false) ) {
        Invoke-Command -Session $Script:session {
            Write-Verbose "$(Log-Date) Switch Internet download security warning back on" | Out-Host
            [Environment]::SetEnvironmentVariable('SEE_MASK_NOZONECHECKS', '0', 'Machine') | Out-Host
            # Set-ExecutionPolicy restricted -Scope CurrentUser
        }
    }

    Write-Host "Test that keys are still configured"
    if ( $InstallScalable -eq $true ) {
        Execute-RemoteBlock $Script:session {  
            try {
                Test-RegKeyValueIsNotNull 'ScalableLicensePrivateKey'
                Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'
            } catch {
                Write-RedOutput "Test-RegKeyValueIsNotNull script block in bake-ide-ami.ps1 is the <No file> in the stack dump below" | Out-Host
                Write-RedOutput $_ | Out-Host
                Write-RedOutput $PSItem.ScriptStackTrace | Out-Host
                cmd /c exit 1
                throw              
            }
        }
    }

    ReConnect-Session

    Write-Host "$(Log-Date) Sysprep"
    Write-Verbose "Use Invoke-Command as the Sysprep will terminate the instance and thus Execute-RemoteBlock will return a fatal error" | Out-Host

    if ( $Cloud -eq 'AWS' ) {
        if ( $Win2012 ) {
            Invoke-Command -Session $Script:session {cmd /c "$ENV:ProgramFiles\Amazon\Ec2ConfigService\ec2config.exe" -sysprep  | Out-Host}
        } else {
            # See here for doco - http://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch.html
            Invoke-Command -Session $Script:session {cd $ENV:ProgramData\Amazon\EC2-Windows\Launch\Scripts | Out-Host}
            Invoke-Command -Session $Script:session {./InitializeInstance.ps1 -Schedule | Out-Host}
            Invoke-Command -Session $Script:session {./SysprepInstance.ps1 | Out-Host}
        }
    } elseif ($Cloud -eq 'Azure' ) {
        $Response = MessageBox "Do you want to run sysprep automatically?" 0x3
        $Response
        if ( $response -eq 0x6 ) {
            Write-Host( "$(Log-Date) Running sysprep automatically")

            # Invoke-Command -Session $Script:session {cd "$env:SystemRoot\system32\sysprep"}
            Invoke-Command -Session $Script:session {
                cd "$env:SystemRoot\system32\sysprep"  | Out-Host;
                cmd /c sysprep /oobe /generalize /shutdown | Out-Host;
            }
        } else {
            $dummy = MessageBox "Run sysprep manually. When complete, click OK on this message box"    
        }            
    }

    Remove-PSSession $Script:session | Out-Host

    # Sysprep will stop the Instance

    if ( $Cloud -eq 'Azure' ) {
        Wait-AzureVMState $svcName $Script:vmname "StoppedVM"

        Write-Host "$(Log-Date) Creating Azure Image"
    
        Write-Verbose "$(Log-Date) Delete image if it already exists" | Out-Host
        $ImageName = "$($VersionText)image"
        Get-AzureVMImage -ImageName $ImageName -ErrorAction SilentlyContinue | Remove-AzureVMImage -DeleteVHD -ErrorAction SilentlyContinue | Out-Host
        Save-AzureVMImage -ServiceName $svcName -Name $Script:vmname -ImageName $ImageName -OSState Generalized | Out-Host

        Write-Host "$(Log-Date) Obtaining signed url for submission to Azure Marketplace"
        .$script:IncludeDir\get-azure-sas-token.ps1 -ImageName $ImageName | Out-Host

    } elseif ($Cloud -eq 'AWS') {
        # Wait for the instance state to be stopped.

        Wait-EC2State $instanceid "Stopped" | Out-Host

        Write-Host "$(Log-Date) Creating AMI"
        
        # Updates already have LANSA-appended text so strip it off if its there
        $SimpleDesc = $($AmazonImage[0].Description)
        $Index = $SimpleDesc.IndexOf( "created on" )
        if ( $index -eq -1 ) {
            $FinalDescription = $SimpleDesc
        } else {
            $FinalDescription = $SimpleDesc.substring( 0, $index - 1 )
        }

        $TagDesc = "$FinalDescription created on $($AmazonImage[0].CreationDate) with LANSA $VersionText installed on $(Log-Date)"
        $AmiName = "$Script:DialogTitle $VersionText $(Get-Date -format "yyyy-MM-ddTHH-mm-ss") $Platform"     # AMI ID must not contain colons
        $amiID = New-EC2Image -InstanceId $Script:instanceid -Name $amiName -Description $TagDesc
 
        $tagName = $amiName # String for use with the name TAG -- as opposed to the AMI name, which is something else and set in New-EC2Image
 
        New-EC2Tag -Resources $amiID -Tags @{ Key = "Name" ; Value = $amiName} # Add tags to new AMI | Out-Host
    
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

    $dummy = MessageBox "Image bake successful" 0
}
catch
{
    . "$Script:IncludeDir\dot-catch-block.ps1"

    Write-Host 'Tidying up'
    if ( Test-Path variable:Script:session ) {
        Remove-PSSession $Script:session | Out-Host
    }

    $dummy = MessageBox "Image bake failed. Fatal error has occurred. Click OK and look at the console log" 0
    return # 'Return' not 'throw' so any output thats still in the pipeline is piped to the console
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
