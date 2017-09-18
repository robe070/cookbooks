try {
    $MyInvocation.MyCommand.Path | Out-File c:\backup.log -Encoding "ASCII"
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    # Load the function to perform the checksum and create the file.
    . $ScriptDir\CreateChecksumFile.ps1
     
    c:\backup.bat
    del 'd:\*.md5'
    CreateChecksumFile md5 'd:\*.zip' | Out-File c:\backup.log -Encoding "ASCII" -Append

    # c:\test.bat
    # CreateChecksumFile md5 'd:\symstore_framework_backup.zip' | Out-File c:\backup.log -Encoding "ASCII" -Append
    
} catch {
    Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au","jason.rampe@lansa.com.au" -Subject "Zipping of Devsrv2 backup failed" -Body "Fatal error. See \\devsrv2\c\backup.log for details" -SmtpServer 10.2.0.241
    throw
}
