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
    # Set-NetFirewallRule is executed via userdata section to open this up to the script-runner's external IP Address.
    $userdata = "<powershell>Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress  $(Get-ExternalIP)</powershell>"

    #Userdata has to be base64 encoded
    $userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))

    # Use at least a 2 CPU instance so that multiple processes may run concurrently.
    $a = New-EC2Instance -ImageId $imageid -MinCount 1 -MaxCount 1 -InstanceType t2.medium -KeyName $keypair -SecurityGroups $securityGroup -UserData $userdataBase64Encoded
    $instanceid = $a.Instances[0].InstanceId

    # Name our instance
    $Tag = New-Object amazon.EC2.Model.Tag
    $Tag.Key = 'Name'
    $Tag.Value = "Bake $Script:aminame"
 
    #apply the tag to the instance
    New-EC2Tag -ResourceID $instanceID -Tag $tag

    #Wait for the running state
    Wait-EC2State $instanceid "Running"

    Write-Output "$instanceid is Running"

    $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid}
    $Script:publicDNS = $a.Instances[0].PublicDnsName

    #Wait for ping to succeed
    while ($true)
    {
        "$(Get-Date) Waiting for network to come alive"
        $ping = Test-Connection -ComputerName $Script:publicDNS -Count 2 -ErrorAction SilentlyContinue
        if ($ping)
        {
            break
        }
        Sleep -Seconds 10
    }

    Write-Output "$instanceid network is alive - $Script:publicDNS"

    # RobG: altering TrustedHost does not seem to be necessary
    #Since the EC2 instance that we are going to create is not a domain joined machine, 
    # it has to be added to the trusted hosts. The computers in the TrustedHosts list are
    #  not authenticated. (i.e.) There is no way for the client to know if it is talking to 
    # the right machine. The client may send credential information to these computers. 
    # Either add the specific DNSName or “*” to trust any machine. Since it is for the testing purpose, I chose to add “*”
    # TODO: add the DNS name of the EC2 instance to the trusted hosts (and remove it at the end)
    # Set-Item WSMan:\localhost\Client\TrustedHosts "$Script:publicDNS" -Force

    # Get-EC2PasswordData is used to extract the password by passing the private key file created earlier. This is tried in a loop until the password is ready.

    $Script:password = $null
    #Wait until the password is available
    #blindly eats all the exceptions, bad idea for a production code.
    while ($Script:password -eq $null)
    {
        "$(Get-Date) Waiting for PasswordData to be available"
        try
        {
            $Script:password = Get-EC2PasswordData -InstanceId $instanceid -PemFile $script:keypairfile -Decrypt
        }
        catch
        {
            # The exception is [System.InvalidOperationException] when the instance is not ready, 
            # which is a very generic erorr so we cannot be specific and just ignore the expected state
            Sleep -Seconds 10
        }
    }
    Write-Output "$instanceid password successfully obtained - '$Script:password'"

    $script:instanceId = $instanceId
}
catch
{
    Write-Error ($_ | format-list | out-string)
}
}