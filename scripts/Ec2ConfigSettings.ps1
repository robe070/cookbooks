# ====================================================
# Set the EC2 config settings
# ====================================================
echo +++++++++++++++++++++++++++++++
echo "Setting EC2Config settings"
echo +++++++++++++++++++++++++++++++
$EC2SettingsFile="C:\Program Files\Amazon\Ec2ConfigService\Settings\Config.xml"
$xml = [xml](get-content $EC2SettingsFile)
$xmlElement = $xml.get_DocumentElement()
$xmlElementToModify = $xmlElement.Plugins

foreach ($element in $xmlElementToModify.Plugin)
{
echo +++++++++++++++++++++++++++++++
echo $element.name
echo +++++++++++++++++++++++++++++++
   if ($element.name -eq "Ec2SetPassword")
   {
      $element.State="Enabled"
   }
   elseif ($element.name -eq "Ec2SetComputerName")
   {
      $element.State="Enabled"
   }
   elseif ($element.name -eq "Ec2HandleUserData")
   {
      $element.State="Enabled"
   }
   elseif ($element.name -eq "Ec2WindowsActivate")
   {
      $element.State="Enabled"
   }
}
$xml.Save($EC2SettingsFile)

echo +++++++++++++++++++++++++++++++
echo "Setting BundleConfig settings"
echo +++++++++++++++++++++++++++++++
$EC2SettingsFile="C:\Program Files\Amazon\Ec2ConfigService\Settings\BundleConfig.xml"
$xml = [xml](get-content $EC2SettingsFile)
$xmlElement = $xml.get_DocumentElement()

foreach ($element in $xmlElement.Property)
{
echo +++++++++++++++++++++++++++++++
echo $element.name
echo +++++++++++++++++++++++++++++++
   if ($element.name -eq "SetPasswordAfterSysprep")
   {
      $element.Value = "Yes"
   }
}
$xml.Save($EC2SettingsFile)
