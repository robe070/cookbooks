<#
.SYNOPSIS

Configure an EC2 Windows instance for Cloud Watch

.EXAMPLE

#>
param(
)
# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

try
{
    $DebugPreference = "Continue"
    $VerbosePreference = "Continue"

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

    exit 0
}
catch
{
    exit 2
}