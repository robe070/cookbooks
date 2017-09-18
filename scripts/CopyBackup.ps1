try {
    $logfile = 'c:\copybackup.log'
    $MyInvocation.MyCommand.Path | Out-File $logfile -Encoding "ASCII"
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    copy-item 'd:\*.*' '\\devsrv\symstore\devsrv2-backup' -Force | Out-File $logfile -Encoding "ASCII" -Append
    
    $Session = New-PSSession devsrv
    Invoke-Command -Session $Session -FilePath "$ScriptDir\CreateChecksumFile.ps1" | Out-File $logfile -Encoding "ASCII" -Append
    Invoke-Command -Session $Session {
        # N.B. This is running on DEVSRV and all references are as if on the machine
        # Also, there is no authority to use the network as no delegation is allowed with Windows Server 2003
        
        $RemotePath = 'D:\devsrv2-backup\*.zip'
        $Algo = 'md5'
        CreateChecksumFile $Algo $RemotePath $true
        # Compare the filenames
        
        # For each zip file, get the names of the source and target checksum files and check if the checksum is the same
        $files = @(Get-ChildItem $RemotePath )
        $files
        $ErrorCount = 0
        foreach ($file in $files ) {
            Write-Output "Zip File $($file.name)"
            $Chkfiles = @(Get-ChildItem "$($file)_*.$Algo")
            foreach ($Chkfile in $Chkfiles ) {
                Write-Output "Checksum File $($Chkfile.name)"
                $split = @($Chkfile -split("$Algo") )
                $SourceCheckSumFile = "$($Split[0])$Algo.tgt"
                if ( (Test-Path $SourceCheckSumFile) ) {
                    Write-Output "Checksum matched for $($Split[0])$Algo.tgt"
                } else {
                    $ErrorCount += 1
                    Write-Output "Checksum mismatch. $($Split[0])$Algo.tgt not found"
                    Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au","jason.rampe@lansa.com.au" -Subject "Copy of Devsrv2 backup to devsrv failed" -Body "Checksum mismatch. $($Split[0])$Algo.tgt not found" -SmtpServer 10.2.0.241
                }
            }
        }        
        
        if ( $ErrorCount -eq 0 ) {
            Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au","jason.rampe@lansa.com.au" -Subject "Copy of Devsrv2 backup to devsrv succeeded" -SmtpServer 10.2.0.241
        }
        
    } | Out-File c:\copybackup.log -Encoding "ASCII" -Append

    Remove-PSSession -Session $Session | Out-File $logfile -Encoding "ASCII" -Append
} catch {
    $_ | format-list | Out-File $logfile -Encoding "ASCII" -Append
    Send-MailMessage -From "user1@lansa.com.au" -To "rob.goodridge@lansa.com.au","jason.rampe@lansa.com.au" -Subject "Copy of Devsrv2 backup to devsrv failed" -Body "Fatal error. See \\devsrv2\c\copybackup.log for details" -SmtpServer 10.2.0.241
    throw
}