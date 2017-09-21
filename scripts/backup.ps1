try {
    $MyInvocation.MyCommand.Path
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    c:\backup.bat

} catch {
    Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au","jason.rampe@lansa.com.au" -Subject "Zipping of Devsrv2 backup failed" -Body "Fatal error. See \\devsrv2\c\backup.log for details" -SmtpServer 10.2.0.241
    throw
}

try {
    # Load the function to perform the checksum and create the file.
    . $ScriptDir\CreateChecksumFile.ps1
     
    del 'd:\*.md5'
    CreateChecksumFile md5 'd:\*.zip'

    # c:\test.bat
    # CreateChecksumFile md5 'd:\symstore_framework_backup.zip'
    
} catch {
    Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au","jason.rampe@lansa.com.au" -Subject "Checksum of Devsrv2 backup failed" -Body "Fatal error. See \\devsrv2\c\backup.log for details" -SmtpServer 10.2.0.241
    throw
}

# Check if the finishing time is before the tape backup starts. The time of it starting is hard coded and so will need to be changed
# when the tape backup starts later.

# Presume thjat this script finishes on the same day as the tape backup.
$TapeHour = 2
$TapeMinute = 40
$Now=(GET-DATE)
$Now.Hour
$Now.Minute
if ( $Now.Hour -gt $TapeHour -or ($Now.Hour -eq $TapeHour -and $Now.Minute -gt $TapeMinute)) {
    $Text = "Devsrv2 backup finished at $($Now.Hour):$($Now.Minute) after tape backup started ($($TapeHour):$($TapeMinute))"
    Write-Output $Text
    Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au" -Subject $Text -Body "Fatal error. See \\devsrv2\c\backup.log for details" -SmtpServer 10.2.0.241
} elseif ($Now.Hour -eq $TapeHour){
    $Text = "Devsrv2 backup finished at $($Now.Hour):$($Now.Minute) It may soon be too late for the tape backup ($($TapeHour):$($TapeMinute))"
    Write-Output $Text
    Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au" -Subject $Text -Body "Warning. See \\devsrv2\c\backup.log for details" -SmtpServer 10.2.0.241
}
