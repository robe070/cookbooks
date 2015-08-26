<#
.SYNOPSIS

AWS and Internet tools

.EXAMPLE

#>

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
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "icmp"; FromPort = -1;   ToPort = -1;   IpRanges = $iprange}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 80;   ToPort = 80;   IpRanges = @("0.0.0.0/0")}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 3389; ToPort = 3389; IpRanges = $iprange}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "udp";  FromPort = 3389; ToPort = 3389; IpRanges = $iprange}
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 5985; ToPort = 5986; IpRanges = $iprange}
    }
}
