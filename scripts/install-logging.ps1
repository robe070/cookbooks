<#
.SYNOPSIS

Modify CloudWatch logging configuration for the Region and Stack

.EXAMPLE


#>
param(
[String]$Stack,
[String]$Region,
[String]$f32bit = 'true'
)

# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

$trusted="NO"

# $DebugPreference = "Continue"
# $VerbosePreference = "Continue"

Write-Debug ("Stack = $Stack")
Write-Debug ("Region = $Region")
Write-Debug ("32bit = $f32bit")

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

    if ($f32bit_bool)
    {
        $APPA = "${ENV:ProgramFiles(x86)}\LANSA"
    }
    else
    {
        $APPA = "${ENV:ProgramFiles}\LANSA"
    }

    # Ensure that Ec2 is not reinstalled during this time. Should already be disabled in Cake.

    Disable-ScheduledTask -TaskName "Ec2ConfigMonitorTask"

    #####################################################################################
    Write-Output ("Turn on CloudWatch Logging")

    $EC2SettingsFile="C:\Program Files\Amazon\Ec2ConfigService\Settings\Config.xml"
    $xml = [xml](get-content $EC2SettingsFile)
    $xmlElement = $xml.get_DocumentElement()
    $xmlElementToModify = $xmlElement.Plugins

    foreach ($element in $xmlElementToModify.Plugin)
    {
        if ($element.name -eq "AWS.EC2.Windows.CloudWatch.PlugIn")
        {
            $element.State="Enabled"
        }
    }
    $xml.Save($EC2SettingsFile)

    #####################################################################################
    Write-Output ("Create a dummy file to stop error messages in ec2configlog.txt when there are no log files")
    New-Item (Join-Path -Path $APPA -ChildPath "log\lx_perf_dummy.log") -type file -force

    #####################################################################################
    # C:\Program Files\Amazon\Ec2ConfigService\Settings\AWS.EC2.Windows.CloudWatch.json
    # 
    #####################################################################################

    $cloudwatch_file = "C:\Program Files\Amazon\Ec2ConfigService\Settings\AWS.EC2.Windows.CloudWatch.json"

    Write-Output ("Updating $cloudwatch_file")

    (Get-Content $cloudwatch_file) |
    Foreach-Object {$_ -replace "ap-southeast-2","$Region"}  | 
    Set-Content ($cloudwatch_file)

    # Use backtick to escape double quotes
    (Get-Content $cloudwatch_file) |
    Foreach-Object {$_ -replace "stack_id","$Stack"}  | 
    Set-Content ($cloudwatch_file)

    Write-Output ("Log configuration completed successfully")

    Write-Output ("ec2config re-reads $cloudwatch_file when restarted")
    Write-Output ("Rebooting to restart ec2config which cannot be restarted by this script as its running this script.")
    Write-Output ("After rebooting, ec2config should continue from the next command")
    Write-Output ("CloudFormation template command requires waitAfterCompletion : forever")
    Restart-Computer
}
catch
{
    Write-Error ("Log configuration failed")
    cmd /c exit 2
}
