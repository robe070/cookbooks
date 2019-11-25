#
#  This script exports consolidated and filtered event logs to CSV
#

Set-Variable -Name EventAgeDays -Value 1     #we will take events for the latest 7 days
Set-Variable -Name LogNames -Value @("Application", "System")  # Checking app and system logs
Set-Variable -Name EventTypes -Value @("Error", "Warning")  # Loading only Errors and Warnings
Set-Variable -Name ExportFolder -Value "c:\temp\"


$el_c = @()   #consolidated error log
$now=get-date
$startdate=$now.adddays(-$EventAgeDays)
$ExportFile=$ExportFolder + "el" + $now.ToString("yyyy-MM-dd---hh-mm-ss") + ".csv"  # we cannot use standard delimiters like ":"

foreach($log in $LogNames)
{
    Write-Host Processing $comp\$log
    $el = get-eventlog -logName $log -After $startdate -EntryType $EventTypes
    $el_c += $el  #consolidating
}
$el_sorted = $el_c | Sort-Object TimeGenerated    #sort by time
Write-Host Exporting to $ExportFile
$el_sorted|Select EntryType, TimeGenerated, Source, EventID, MachineName | Export-CSV $ExportFile -NoTypeInfo  #EXPORT
Write-Host Done!