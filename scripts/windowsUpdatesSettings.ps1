#####################################################################################
# Set Windows Update settings
#####################################################################################
# The following settings can be found in Windows under "Windows Update"/"Change settings"
$autoUpdateSettings = (New-Object -ComObject "Microsoft.Update.AutoUpdate").Settings
if ( $autoUpdateSettings )
{
    # Set to "Check for updates but let me choose whether to download and install them".
    # We want to control when updates get installed.
    $autoUpdateSettings.NotificationLevel = 2

    # This sets the "Give me recommended updates the same way I recieve important updates"
    $autoUpdateSettings.IncludeRecommendedUpdates = $true
    $autoUpdateSettings.Save()
}
else
{
    Write-Output "Cannot adjust Windows Update Settings through Remote PS"
}
# This sets "Give me updates for other Microsoft products when I update Windows"
$ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
$ServiceManager.ClientApplicationID = "My App"
$ServiceManager.AddService2( "7971f918-a847-4430-9279-4a52d1efe18d",7,"")
