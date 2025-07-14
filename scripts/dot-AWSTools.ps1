<#
.SYNOPSIS

AWS and Internet tools

.EXAMPLE

#>

# N.B. Get-ExternalIP must not be run very often otherwise url may throttle the access
function Get-ExternalIP {
    if ( -not $script:externalip )
    {
        $Ip = (Invoke-WebRequest "https://ipv4.myexternalip.com/raw")

        # strip CR or LF from string and return Ip Address
        $script:externalip = $Ip.content -replace "`t|`n|`r",""
    }
    $script:externalip # Return value of function
}

function Create-Ec2SecurityGroup
{
<#  .Synopsis      Creates a security group named $script.SG.  .Description Adds firewall exceptions for PowerShell Remoting, Remote Desktop and ICMP. Allowing ICMP enables “ping” to function, helps with debugging. The example below opens up to any IpRange, which means that the EC2 instance can be contacted from anywhere in the world. This is due to Azure DevOps sometimes using a different external ip and allowing a developer to access EC2 instances created by AzureDevOps  #>
    param([string[]]$ExternalIPAddresses)
    $groupExists = $true

    try
    {
        $Groups = Get-EC2SecurityGroup -GroupNames $script:SG -ea SilentlyContinue
    }
    catch
    {
        $groupExists = $false
    }

    if ( $groupExists ) {
        Write-Host( "GroupId = $Groups.GroupId")
        Remove-EC2SecurityGroup -GroupId $Groups.GroupId -Force | Out-Default | Write-Host
    }

    $externalip = Get-ExternalIP
    $externalipcidr = "$externalip/32"
    if ( ($ExternalIPAddresses -contains $externalipcidr) ) {
        Write-Host "SG already enabled for Default IP $externalipcidr"
    } else {
        Write-Host "Enabling SG for Default IP $externalipcidr"
        $ExternalIPAddresses += $externalipcidr
    }

    if ( $ExternalIPAddresses -And $ExternalIPAddresses.count -gt 0 ) {
        Write-Host "Enabling SG for IP $ExternalIPAddresses"
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "icmp"; FromPort = -1;   ToPort = -1;   IpRanges = @($ExternalIPAddresses)} -ErrorAction SilentlyContinue | Out-Default | Write-Host
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 3389; ToPort = 3389; IpRanges = @($ExternalIPAddresses)} -ErrorAction SilentlyContinue | Out-Default | Write-Host
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "udp";  FromPort = 3389; ToPort = 3389; IpRanges = @($ExternalIPAddresses)} -ErrorAction SilentlyContinue | Out-Default | Write-Host
        Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 5985; ToPort = 5986; IpRanges = @($ExternalIPAddresses)} -ErrorAction SilentlyContinue | Out-Default | Write-Host

        # $ipPermissions = @()

        # # Add the first permission
        # $ipPermission1 = New-Object Amazon.EC2.Model.IpPermission
        # $ipPermission1.IpProtocol = "icmp"
        # $ipPermission1.FromPort = -1
        # $ipPermission1.ToPort = -1
        # $ipPermission1.IpRanges.Add($iprange)
        # $ipPermissions += $ipPermission1

        # # Add the second permission
        # $ipPermission2 = New-Object Amazon.EC2.Model.IpPermission
        # $ipPermission2.IpProtocol = "tcp"
        # $ipPermission2.FromPort = 3389
        # $ipPermission2.ToPort = 3389
        # $ipPermission2.IpRanges.Add($iprange)
        # $ipPermissions += $ipPermission2

        # # Add the third permission
        # $ipPermission2 = New-Object Amazon.EC2.Model.IpPermission
        # $ipPermission2.IpProtocol = "udp"
        # $ipPermission2.FromPort = 3389
        # $ipPermission2.ToPort = 3389
        # $ipPermission2.IpRanges.Add($iprange)
        # $ipPermissions += $ipPermission2

        # # Add the fourth permission
        # $ipPermission2 = New-Object Amazon.EC2.Model.IpPermission
        # $ipPermission2.IpProtocol = "tcp"
        # $ipPermission2.FromPort = 5985
        # $ipPermission2.ToPort = 5986
        # $ipPermission2.IpRanges.Add($iprange)
        # $ipPermissions += $ipPermission2

        # Grant-EC2SecurityGroupIngress -GroupId $GroupId -IpPermissions $ipPermissions
    }
    # $externalip = Get-ExternalIP
    # $externalipcidr = "$externalip/32"

    # Write-Host "Enabling SG for Default IP $externalipcidr"

    # Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "icmp"; FromPort = -1;   ToPort = -1;   IpRanges = $externalipcidr} -ErrorAction SilentlyContinue | Out-Default | Write-Host
    # Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 3389; ToPort = 3389; IpRanges = $externalipcidr} -ErrorAction SilentlyContinue | Out-Default | Write-Host
    # Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "udp";  FromPort = 3389; ToPort = 3389; IpRanges = $externalipcidr} -ErrorAction SilentlyContinue | Out-Default | Write-Host
    # Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 5985; ToPort = 5986; IpRanges = $externalipcidr} -ErrorAction SilentlyContinue | Out-Default | Write-Host

    Grant-EC2SecurityGroupIngress -GroupName $script:SG -IpPermissions @{IpProtocol = "tcp";  FromPort = 80;   ToPort = 80;   IpRanges = @("0.0.0.0/0")} -ErrorAction SilentlyContinue | Out-Default | Write-Host
}
