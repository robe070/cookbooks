<#
.SYNOPSIS

Install the LANSA IDE.
Creates a SQL Server Database then installs from the DVD image

Requires the environment that a LANSA Cake provides, particularly an AMI license.

N.B. It is vital that the user id and password supplied pass the password rules.
E.g. The password is sufficiently complex and the userid is not duplicated in the password.
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

.EXAMPLE


#>
param(
[String]$server_name=$env:COMPUTERNAME,
[String]$dbname='LANSA',
[String]$dbuser = 'administrator',
[String]$dbpassword = 'password',
[String]$webuser = 'PCXUSER2',
[String]$webpassword = 'PCXUSER@122',
[String]$f32bit = 'true',
[String]$SUDB = '1',
[String]$UPGD = 'false',
[String]$maxconnections = '20',
[String]$wait = 'true'
)

# If environment not yet set up, it should be running locally, not through Remote PS
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
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

if (!(Test-Path -Path $Script:ScriptTempPath)) {
    New-Item -ItemType directory -Path $Script:ScriptTempPath | Write-Host
}

# Put first output on a new line in cfn_init log file
Write-Host ("`r`n")

# $trusted=$true

Write-Debug ("Server_name = $server_name") | Write-Host
Write-Debug ("dbname = $dbname") | Write-Host
Write-Debug ("dbuser = $dbuser") | Write-Host
Write-Debug ("webuser = $webuser") | Write-Host
Write-Debug ("32bit = $f32bit") | Write-Host
Write-Debug ("SUDB = $SUDB") | Write-Host
Write-Debug ("UPGD = $UPGD") | Write-Host
Write-Debug ("WAIT = $Wait") | Write-Host

try
{
    if ( $f32bit -eq 'true' -or $f32bit -eq '1')
    {
        $f32bit_bool = $true
    }
    else
    {
        $f32bit_bool = $false
    }

    if ( $UPGD -eq 'true' -or $UPGD -eq '1')
    {
        $UPGD_bool = $true
    }
    else
    {
        $UPGD_bool = $false
    }

    Write-Debug ("UPGD_bool = $UPGD_bool" ) | Write-Host

    $x_err = (Join-Path -Path $ENV:TEMP -ChildPath 'x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue | Write-Host

    $Language = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Language').Language
    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    # $InstallSQLServer = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'InstallSQLServer').InstallSQLServer

    # On initial install disable TCP Offloading

    if ( -not $UPGD_bool )
    {
        Disable-TcpOffloading | Write-Host
    }

    ######################################
    # Require MS C runtime to be installed
    ######################################

    if ( (-not $UPGD_bool) )
    {
        Write-Host ("$(Log-Date) Ensure SQL Server Powershell module is loaded.")

        Write-Verbose ("Loading this module changes the current directory to 'SQLSERVER:\'. It will need to be changed back later") | Write-Host

        Import-Module “sqlps” -DisableNameChecking | Write-Host

        if ( $SUDB -eq '1' -and -not $UPGD_bool)
        {
            Create-SqlServerDatabase $server_name $dbname | Write-Host
        }

        #####################################################################################
        Write-Host ("$(Log-Date) Enable Named Pipes on database")
        #####################################################################################

        if ( Change-SQLProtocolStatus -server $server_name -instance "MSSQLSERVER" -protocol "NP" -enable $true )
        {
            $service = get-service "MSSQLSERVER"
            restart-service $service.name -force  | Write-Host    #Restart SQL Services
        }

        Write-Verbose ("Change current directory from 'SQLSERVER:\' back to the file system so that file pathing works properly") | Write-Host
        Set-Location "c:"
    }

    if ($f32bit_bool)
    {
        $APPA = "${ENV:ProgramFiles(x86)}\LANSA"
    }
    else
    {
        $APPA = "${ENV:ProgramFiles}\LANSA"
    }

    #####################################################################################
    Write-Host ("$(Log-Date) Pull down DVD image ")
    #####################################################################################
    cmd /c mkdir $Script:DvdDir '2>nul'
    $S3DVDImageDirectory = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'DVDUrl').DVDUrl

    if ( $Cloud -eq "AWS" ) {
        cmd /c aws s3 sync  $S3DVDImageDirectory $Script:DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--exclude" "*setup/Installs/MSSQLEXP/*" "--delete" | Out-Null
    } elseif ( $Cloud -eq "Azure" ) {
        cmd /c AzCopy /Source:$S3DVDImageDirectory /Dest:$Script:DvdDir /S /XO /Y /MT | Out-Null
    }
    if ( $LastExitCode -ne 0 )
    {
        throw "Error downloading DVD Image"
    }

    if ( $UPGD_bool )
    {
        #####################################################################################
        Write-Host ("$(Log-Date) Installing all EPCs")
        #####################################################################################

        cmd /c $Script:DvdDir\EPC\allepcs.exe """$APPA""" | Write-Host
        if ( $LastExitCode -ne 0 )
        {
            throw "Error installing EPCs"
        }
    }
    else
    {
        #####################################################################################
        Write-Host ("$(Log-Date) Installing the application")
        #####################################################################################

        Install-VisualLansa
    }

    #####################################################################################
    Write-Host ("$(Log-Date) Pull down latest Visual LANSA updates")
    #####################################################################################
    cmd /c "$APPA\integrator\jsmadmin\strjsm.exe" "-sstop" # Must stop JSM otherwise aws s3 sync will throw errors accessing files which are locked

    $S3VisualLANSAUpdateDirectory = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'VisualLANSAUrl').VisualLANSAUrl

    if ( $Cloud -eq "AWS" ) {
        cmd /c aws s3 sync  $S3VisualLANSAUpdateDirectory "$APPA" | Write-Host
    } elseif ( $Cloud -eq "Azure" ) {
        cmd /c AzCopy /Source:$S3VisualLANSAUpdateDirectory /Dest:"$APPA" /S /XO /Y /MT | Write-Host
    }
    if ( $LastExitCode -ne 0 )
    {
        throw "Error downloading Visual LANSA updates"
    }

    #####################################################################################
    Write-Host ("$(Log-Date) Pull down latest Integrator updates")
    #####################################################################################

    $S3IntegratorUpdateDirectory = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'IntegratorUrl').IntegratorUrl

    if ( $Cloud -eq "AWS" ) {
        cmd /c aws s3 sync  $S3IntegratorUpdateDirectory "$APPA\Integrator"  | Write-Host
    } elseif ( $Cloud -eq "Azure" ) {
        cmd /c AzCopy /Source:$S3IntegratorUpdateDirectory /Dest:"$APPA\Integrator" /S /XO /Y /MT | Write-Host
    }
    if ( $LastExitCode -ne 0 )
    {
        throw "Error downloading Integrator updates"
    }
    cmd /c "$APPA\integrator\jsmadmin\strjsm.exe" "-sstart" | Write-Host

    Write-Host "$(Log-Date) IDE Installation completed"
    Write-Host ""

    #####################################################################################
    Write-Host ("$(Log-Date) Test if post install x_run processing had any fatal errors")
    #####################################################################################

    if ( (Test-Path -Path $x_err) )
    {
        Write-Verbose ("Signal to caller that the installation has failed") | Write-Host

        throw "$x_err exists which indicates an installation error has occurred."
    }

    if ( -not $UPGD_bool )
    {
        # This code creates pendingfilerenameoperations so moved to after LANSA Install which otherwise will require a reboot before installing SQL Server.
        Start-WebAppPool -Name "DefaultAppPool" | Write-Host

        # Speed up the start of the VL IDE
        # Switch off looking for software license keys

        [Environment]::SetEnvironmentVariable('LSFORCEHOST', 'NO-NET', 'Machine') | Write-Host
    }

    if ( -not $UPGD_bool )
    {
        #####################################################################################
        Write-Host ("$(Log-Date) Import test case")
        #####################################################################################

        # Note: have not been able to find a way to pass a parameter with spaces in and NOT have the entire parameter surrounded by quotes by Powershell
        # So $import path must not have spaces in it.

        $import = "$script:IncludeDir\..\Tests\WAMTest"
        $x_dir = "$APPA\x_win95\x_lansa\execute"
        Set-Location $x_dir | Write-Host
        cmd /c "x_run.exe" "PROC=*LIMPORT" "LANG=$Language" "PART=DEX" "USER=$webuser" "DBIT=MSSQLS" "DBII=$dbname" "DBTC=Y" "ALSC=NO" "BPQS=Y" "EXPR=$import" "LOCK=NO" | Write-Host

        if ( $LastExitCode -ne 0 -or (Test-Path -Path $x_err) )
        {
            Write-Verbose ("Signal to caller that the import has failed") | Write-Host

            throw "$x_err exists or an exception has been thrown which indicate an installation error has occurred whilst importing $import."
        }

        #####################################################################################
        Write-Host ("$(Log-Date) Shortcuts")
        #####################################################################################

        # Sysprep file needs to be put in a specific place for AWS. But on Azure we cannot use an unattend file
        if ( $Cloud -eq "AWS" ) {
            if ( Test-Path "$ENV:ProgramFiles\amazon\Ec2ConfigService\sysprep2008.xml" ) {
                Copy-Item "$Script:GitRepoPath/scripts/sysprep2008.xml" "$ENV:ProgramFiles\amazon\Ec2ConfigService\sysprep2008.xml" | Write-Host
            }
        }

        $StartHereHtm = "CloudStartHere$Language.htm"
        Copy-Item "$Script:GitRepoPath/scripts/$StartHereHtm" "$ENV:ProgramFiles\CloudStartHere.htm" | Write-Host

        switch ($Language) {
            'FRA' {
                $StartHereLink = "Commencer ici"
                $EducationLink = "Education"
                $QuickConfigLink = "LANSA configuration rapide"
                $InstallEPCsLink = "Installer les EPCs"
            }
            'JPN' {
                $StartHereLink = "ここから開始"
                $EducationLink = "教育"
                $QuickConfigLink = "LANSA クイック    構成"
                $InstallEPCsLink = "EPC をインストール"
            }
            default{
                $StartHereLink = "Start Here"
                $EducationLink = "Education"
                $QuickConfigLink = "Lansa Quick Config"
                $InstallEPCsLink = "Install EPCs"
                $StartHereHtm = "CloudStartHereENG.htm"
            }
        }

        New-Shortcut "${ENV:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" "CommonDesktop\$StartHereLink.lnk" -Description "Start Here"  -Arguments "file://$Script:GitRepoPath/scripts/$StartHereHtm" -WindowStyle "Maximized" | Write-Host
        New-Shortcut "${ENV:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" "CommonDesktop\$EducationLink.lnk" -Description "Education"  -Arguments "http://www.lansa.com/education/" -WindowStyle "Maximized" | Write-Host
        New-Shortcut "$Script:DvdDir\setup\LansaQuickConfig.exe" "CommonDesktop\$QuickConfigLink.lnk" -Description "Quick Config" | Write-Host
        New-Shortcut "$ENV:SystemRoot\system32\WindowsPowerShell\v1.0\powershell.exe" "CommonDesktop\$InstallEPCsLink.lnk" -Description "Install EPCs" -Arguments "-ExecutionPolicy Bypass -Command ""c:\lansa\Scripts\install-lansa-ide.ps1 -upgd true""" | Write-Host

        if ( $Cloud -eq "AWS" ) {
            # In AWS the administrator user name is known and same as current user so we can launch when administrator user logs in
            $Hive = "HKCU"
        } elseif ( $Cloud -eq "Azure" ) {
            # In Azure the administrator name is not known so forced to launch when machine starts - before desktop is available
            # And adding trusted sites does not seem to work globally - TBA
            $Hive = "HKLM"
        }

        Remove-ItemProperty -Path HKLM:\Software\LANSA -Name StartHereShown –Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "StartHere" -Value "powershell -executionpolicy Bypass -file $Script:GitRepoPath\scripts\show-start-here.ps1" | Write-Host

        PlaySound

        Add-TrustedSite "*.addthis.com" $Hive | Write-Host
        Add-TrustedSite "*.adobe.com" $Hive | Write-Host
        Add-TrustedSite "*.adobe.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.adobelogin.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.adobetag.com" $Hive | Write-Host
        Add-TrustedSite "*.cloudfront.com" $Hive | Write-Host
        Add-TrustedSite "*.cloudfront.net" $Hive | Write-Host
        Add-TrustedSite "*.cloudfront.net" $Hive "https" | Write-Host
        Add-TrustedSite "*.demdex.net" $Hive "https" | Write-Host
        Add-TrustedSite "*.google.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.googleapis.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.google-analytics.com" $Hive | Write-Host
        Add-TrustedSite "*.google-analytics.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.googleadservices.com" $Hive | Write-Host
        Add-TrustedSite "*.img.en25.com" $Hive | Write-Host
        Add-TrustedSite "*.lansa.com" $Hive | Write-Host
        Add-TrustedSite "*.myabsorb.com" $Hive | Write-Host
        Add-TrustedSite "*.myabsorb.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.gstatic.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.youtube.com" $Hive | Write-Host
        Add-TrustedSite "*.youtube.com" $Hive "https" | Write-Host
        Add-TrustedSite "*.ytimg.com" $Hive "https" | Write-Host

        if ( $Cloud -eq "Azure" ) {
            Write-Host "Set JSM Service dependencies"
            Write-Verbose "Integrator Service on Azure requires the Azure services it tests for licensing to be dependencies" | Write-Host
            Write-Verbose "so that they are running when the license check is made by the Integrator service." | Write-Host
            $JSMServices = @(Get-WmiObject win32_service -Filter 'Name like "LANSA Integrator JSM Administrator Service%"')
            $Service = $null
            foreach ( $JSMService in $JSMServices ) {
                if ( $JSMService.Pathname -like $APPA) {
                    $Service = $JSMService
                    break
                }
            }

            if ( -not $Service ) {
                $JSMServices | Select-object Name, DisplayName, State, Pathname | Format-Table | Out-Host
                throw "JSM Instance service not found for $APPA"
            }
            $Service.Name | Out-Host
            $RegKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\" + $Service.Name
            $RegKeyPath | Out-Host
            New-ItemProperty  -Path $RegKeyPath -Name DependOnService  -PropertyType MultiString -Value @("WindowsAzureGuestAgent","WindowsAzureTelemetryService") -Force  | Out-Host

            @(get-service $service.Name) | Format-Table Name, DisplayName, Status, StartType, DependentServices, ServicesDependedOn | Out-Host
        }
    } else {
        Remove-ItemProperty -Path HKLM:\Software\LANSA -Name StartHereShown –Force -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host ("$(Log-Date) Installation completed successfully")
}
catch
{
    $_ | Write-Host
    Write-RedOutput ("$(Log-Date) Installation error") | Write-Host
    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Write-Host

    Write-RedOutput "install-lansa-ide.ps1 is the <No file> in the stack dump below" | Write-Host
    throw
}
finally
{
    Write-Host ("$(Log-Date) See LansaInstallLog.txt and other files in $ENV:TEMP for more details.")

    # Wait if we are upgrading so the user can see the results
    if ( $UPGD_bool -and $Wait -eq 'true')
    {
        Write-Host ""
        Write-Host "Press any key to continue ..."

        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

PlaySound

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
