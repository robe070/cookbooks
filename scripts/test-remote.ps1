<#
.SYNOPSIS

test remote connection architecture.

Requires a running instance thats already beein initialised with git, etc.

.DESCRIPTION

.EXAMPLE


#>

param (
    [Parameter(Mandatory=$false)]
    [string]
    $instanceid='i-036df655f615fab66',

    [Parameter(Mandatory=$false)]
    [string]
    $PublicDNS='ec2-54-252-146-21.ap-southeast-2.compute.amazonaws.com',

    [Parameter(Mandatory=$false)]
    [string]
    $AdminUserName='Administrator',

    [Parameter(Mandatory=$false)]
    [string]
    $AdminPassword='wZqYnW(rpnp=3ln=QiDdeCfDiW6%xQLe',

    [Parameter(Mandatory=$false)]
    [string]
    $Cloud='AWS'

    )

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


try
{
    # Clear out the msgbox object in case its been run already
    $Script:msgbox = $null
    $Script:Session = $null
    $Script:DialogTitle = 'Test Remote error handling'
    $Script:instanceid= $instanceid
    $Script:publicDNS = $PublicDNS

    cmd /c exit 0 # set $LASTERRORCODE

    Write-Host ("$(Log-Date) Allow Remote Powershell session to any host. If it fails you are not running as Administrator!")
    enable-psremoting -SkipNetworkProfileCheck -force
    set-item wsman:\localhost\Client\TrustedHosts -value * -force

    # Remote PowerShell
    $securepassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($AdminUserName, $securepassword)

    ReConnect-Session

    Execute-RemoteScript -Session $Script:session -FilePath $script:IncludeDir\remote-script.ps1

    MessageBox "Image bake successful" 0
}
catch
{
    . "$Script:IncludeDir\dot-catch-block.ps1"
    
    MessageBox "Image bake failed. Fatal error has occurred. Click OK and look at the console log" 0
    return # 'Return' not 'throw' so any output thats still in the pipeline is piped to the console
} finally {
    Write-Host 'Tidying up'
    Remove-PSSession $Script:session | Out-Host    
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
