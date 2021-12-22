Write-Host "Win32_VideoController"
$video_property = "AdapterRAM", "Name", "VideoProcessor"

Get-WmiObject -class Win32_VideoController -Property  $video_property | Select-Object -Property $video_property | format-List

###############################################

Write-Host "Win32_Processor"
$video_property = "Manufacturer", "Name", "ProcessorId"

Get-WmiObject -class Win32_Processor -Property  $video_property | Select-Object -Property $video_property | format-List

###############################################

Write-Host "Win32_BaseBoard"
$video_property = "Manufacturer", "Name", "SerialNumber"

Get-WmiObject -class Win32_BaseBoard -Property  $video_property | Select-Object -Property $video_property | format-List

###############################################

Write-Host "Win32_BIOS"
$video_property = "Manufacturer", "SerialNumber"

Get-WmiObject -class Win32_BIOS -Property  $video_property | Select-Object -Property $video_property | format-List

###############################################

Write-Host "DigitalProductId"
$DigitalProductIdReg = Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion"  -Name 'DigitalProductId' -ErrorAction SilentlyContinue
$hex = ([System.BitConverter]::ToString([byte[]]$DigitalProductIdReg.DigitalProductId)).Replace('-','')
$hex