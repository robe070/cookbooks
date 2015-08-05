<#
.SYNOPSIS

Wait for an EC2 instance to reach a desired state.

.EXAMPLE

#>

# Includes
. "$script:IncludeDir\dot-New-ErrorRecord.ps1"

function Create-EC2Instance
{
Param (
[parameter(Mandatory=$true)]    [string]$imageid,
[parameter(Mandatory=$true)]    [string]$keypair,
[parameter(Mandatory=$true)]    [string]$securityGroup,
[parameter(Mandatory=$false)]   [string]$region
)
try
{
    # By default, Windows Firewall restricts PS remoting to local subnet only. 
    # Set-NetFirewallRule is executed via userdata section to open this up to any address.
    $userdata = "<powershell>Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress  $(Get-ExternalIP)</powershell>"

    #Userdata has to be base64 encoded
    $userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))

    $a = New-EC2Instance -ImageId $imageid -MinCount 1 -MaxCount 1 -InstanceType t1.micro -KeyName $keypair -SecurityGroups $securityGroup -UserData $userdataBase64Encoded
    $instanceid = $a.Instances[0].InstanceId

    #Wait for the running state
    Wait-EC2State $instanceid "Running"

    $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid}
    $Script:publicDNS = $a.Instances[0].PublicDnsName

    #Wait for ping to succeed
    while ($true)
    {
        ping $Script:publicDNS
        if ($LASTEXITCODE -eq 0)
        {
            break
        }
        "$(Get-Date) Waiting for ping to succeed"
        Sleep -Seconds 10
    }

    # Get-EC2PasswordData is used to extract the password by passing the private key file created earlier. This is tried in a loop until the password is ready.

    $password = $null
    #Wait until the password is available
    #blindsly eats all the exceptions, bad idea for a production code.
    while ($Script:password -eq $null)
    {
        try
        {
            $Script:password = Get-EC2PasswordData -InstanceId $instanceid -PemFile $script:keypairfile -Decrypt
        }
        catch
        {
            "$(Get-Date) Waiting for PasswordData to be available"
            Sleep -Seconds 10
        }
    }
    $script:instanceId = $instanceId
}
catch
{
    Write-Error ($_ | format-list | out-string)
}
}