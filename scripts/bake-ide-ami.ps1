<#
.SYNOPSIS

Install a LANSA MSI.
Creates a SQL Server Database then installs the MSI

Requires the environment that a LANSA Cake provides, particularly an AMI license.

# N.B. It is vital that the user id and password supplied pass the password rules. 
E.g. The password is sufficiently complex and the userid is not duplicated in the password. 
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

.EXAMPLE


#>
$script:IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path

# Includes
. "$script:IncludeDir\dot-wait-EC2State.ps1"
. "$script:IncludeDir\dot-Create-EC2Instance"

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# N.B. Get-ExternalIP must not be run very often otherwise url may throttle the access
function Get-ExternalIP {
    if ( -not $script:externalip )
    {
        $Ip = (Invoke-WebRequest "http://ipv4.myexternalip.com/raw")
 
        # strip CR or LF from string and return Ip Address
        $script:externalip = $Ip.content -replace "`t|`n|`r",""
    }
    $script:externalip
}

function Create-Ec2SecurityGroup
{
<#  .Synopsis      Creates a security group named $script.SG.  .Description Adds firewall exceptions for PowerShell Remoting, Remote Desktop and ICMP. Allowing ICMP enables “ping” to function, helps with debugging. The example below opens up to any IpRange, which means that the EC2 instance can be contacted from anywhere in the world.   #>
    $groupExists = $true
    try
    {
        Get-EC2SecurityGroup -GroupNames $script:SG -ea SilentlyContinue
    }
    catch
    {
        $groupExists = $false
    }

    if ( -not $groupExists )
    {
        $externalip = Get-ExternalIP
        $iprange = @("$externalip/32")
        $groupid = New-EC2SecurityGroup $script:SG  -Description "Temporary security to bake an ami"
        Get-EC2SecurityGroup -GroupNames $script:SG
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "icmp"; FromPort = -1; ToPort = -1; IpRanges = $iprange}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp"; FromPort = 3389; ToPort = 3389; IpRanges = $iprange}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "udp"; FromPort = 3389; ToPort = 3389; IpRanges = $iprange}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp"; FromPort = 5985; ToPort = 5986; IpRanges = $iprange}
    }
}

###############################################################################
# Main program loigic
###############################################################################

Set-StrictMode -Version Latest

try
{
    $script:SG = "bake-ami"
    # $script:externalip = "103.231.159.65"
    $script:externalip = $null
    $script:keypair = "RobG_id_rsa"
    $script:keypairfile = "$ENV:USERPROFILE\\.ssh\\id_rsa"
    $script:aminame = "LANSA IDE $(Get-Date -format s)"
    $script:licensekeypassword = $ENV:cloud_license_key
    $script:gitbranch = 'marketplace-and-stt'
    $script:ChefRecipeLocation = "$script:IncludeDir\..\ChefCookbooks"
    $Script:GitRepoPath = "c:\lansa"

    Create-Ec2SecurityGroup

    # First image found is presumed to be the latest image.
    # Force it into a list so that if one image is returned the variable may be used identically.

    $a = @(Get-EC2Image -Filters @{Name = "name"; Values = "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_RTM_Express*"})
    $ImageName = $a.Name[0]
    $Script:Imageid = $a.ImageId[0]
    Write-Output "Using Base Image $ImageName $Script:ImageId"

    Create-EC2Instance $Script:Imageid $script:keypair $script:SG


    # Remote PowerShell
    # The script below establishes a remote session, invokes a remote command (using Invoke-Command), then cleans up the session. The remote command executed is “Invoke-WebRequest” to obtain the userdata. Since the instance might not be fully initialized, this is tried in a loop.

     $securepassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
     # $securepassword = ConvertTo-SecureString 'cy$hyJe)QaJ' -AsPlainText -Force

    $creds = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

    # Wait until PSSession is available
    while ($true)
    {
        "$(Get-Date) Waiting for remote PS connection"
        $session = New-PSSession $Script:publicDNS -Credential $creds -ErrorAction SilentlyContinue
        if ($session -ne $null)
        {
            break
        }

        Sleep -Seconds 10
    }

    Write-Output "$Script:instanceid remote PS connection obtained"

    # Simple test of session: Invoke-Command -Session $session {(Invoke-WebRequest http://169.254.169.254/latest/user-data).RawContent}

    # Example of uploading a file. Does not seem to be needed as all files are in git apart from chocolatey 
    # which is installed from the Chocolatey web site and git which is installed using choco.
    # $filename = "chef-client-12.1.1-1.msi"
    # &"$script:IncludeDir\Send-RemotingFile.ps1" $Session $Script:publicDNS "$script:IncludeDir\..\PackerScripts\$filename" "C:\Program Files\Amazon\$filename"

    
    # First we need to install Chocolatey
    Invoke-Command -Session $session {Set-ExecutionPolicy Unrestricted -Scope CurrentUser}
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -ne 0 ) {throw 1}    

    Invoke-Command -Session $session -FilePath "$script:IncludeDir\getchoco.ps1"
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -ne 0 ) {throw 1}    
    
    # Then we install git using chocolatey and pull down the rest of the files
    Invoke-Command -Session $session -FilePath $script:IncludeDir\installGit.ps1 -ArgumentList  @($script:gitbranch, $true)
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -ne 0 ) {throw 1}    

    # From now on we execute files (scriptBlock) directly on the remote system, not script files uploaded from the local system
    # The contents of the curly braces is uploaded and run as is on the remote. So variables are NOT expanded here. Hence all the 
    # global variables need to be reflected into the remote system
    Invoke-Command -Session $session -ScriptBlock { $Script:GitRepoPath = "c:\lansa"}
    Invoke-Command -Session $session -ScriptBlock { $Script:GitRepoPath }
    Invoke-Command -Session $session -ScriptBlock { "$Script:GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"}
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -ne 0 ) {throw 1}    


    Invoke-Command -Session $session {Set-ExecutionPolicy restricted -Scope CurrentUser}
    Remove-PSSession $session

    # Stop the Instance
    Get-EC2Instance -Filter @{Name = "instance-id"; Values = $Script:instanceid} | Stop-EC2Instance -Force -Terminate

    # Wait for the instance state to be stopped.
    Wait-EC2State $instanceid "terminated"

    # Can't remove security group whilst instance is not terminated
    return

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