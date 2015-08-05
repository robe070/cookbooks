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
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "icmp"; FromPort = -1; ToPort = -1; IpRanges = $iprange }
        $ipPermissions = New-Object Amazon.EC2.Model.IpPermission
        $ipPermissions.IpProtocol = "tcp"
        $ipPermissions.FromPort = 3389
        $ipPermissions.ToPort = 3389
        $ipPermissions.IpRanges = $iprange
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions $ipPermissions
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "udp"; FromPort = 3389; ToPort = 3389; IpRanges = $iprange}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp"; FromPort = 5985; ToPort = 5986; IpRanges = $iprange}
    }
}

###############################################################################
# Main program loigic
###############################################################################

try
{
    # Since the EC2 instance that we are going to create is not a domain joined machine, 
    # it has to be added to the trusted hosts. The computers in the TrustedHosts list are
    #  not authenticated. (i.e.) There is no way for the client to know if it is talking to 
    # the right machine. The client may send credential information to these computers. 
    # Either add the specific DNSName or “*” to trust any machine. Since it is for the testing purpose, I chose to add “*”
    # TODO: add the DNS name of the EC2 instance to the trusted hosts (and remove it at the end)
    Set-Item WSMan:\localhost\Client\TrustedHosts "*" -Force

    $script:SG = "bake-ide-ami"
    # $script:externalip = "103.231.159.65"
    $script:externalip = $null
    $script:keypair = "RobG_id_rsa"
    $script:keypairfile = "$ENV:HOME\\.ssh\\id_rsa"

    Create-Ec2SecurityGroup

    # First image found is presumed to be the latest image.
    # Force it into a list so that if one image is returned the variable may be used identically.

    $a = @(Get-EC2Image -Filters @{Name = "name"; Values = "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_RTM_Express*"})
    $ImageName = $a.Name[0]
    $Imageid = $a.ImageId[0]
    Write-Output "Using Base Image $ImageName $ImageId"

    Create-EC2Instance $Imageid $script:keypair $script:SG

    # Remote PowerShell
    # The script below establishes a remote session, invokes a remote command (using Invoke-Command), then cleans up the session. The remote command executed is “Invoke-WebRequest” to obtain the userdata. Since the instance might not be fully initialized, this is tried in a loop.

#     $securepassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
     $securepassword = ConvertTo-SecureString 'cy$hyJe)QaJ' -AsPlainText -Force

    $creds = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

    # Wait until PSSession is available
    while ($true)
    {
        # $s = New-PSSession $Script:publicDNS -Credential $creds 2>$null
        $s = New-PSSession $Script:publicDNS -Credential $creds
        if ($s -ne $null)
        {
            break
        }

        "$(Get-Date) Waiting for remote PS connection"
        Sleep -Seconds 10
    }

    Invoke-Command -Session $s {(Invoke-WebRequest http://169.254.169.254/latest/user-data).RawContent}

    Remove-PSSession $s

    # Stop the Instance
    Get-EC2Instance -Filter @{Name = "instance-id"; Values = $Script:instanceid} | Stop-EC2Instance -Force

    # Wait for the instance state to be stopped.
    Wait-EC2State $instanceid "Stopped"

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