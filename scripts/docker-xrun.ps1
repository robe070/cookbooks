$logFile='c:\temp\log.txt'
if ( Test-Path -Path $logFile ) {
   del $logFile
}
cd c:\ide\x_win95\x_lansa\execute
$ENV:temp = 'c:\ide\x_win95\x_lansa\tmp'

# x_lansa.pro is presumed to contain part, lang and DB parameters
pwd | Write-Host
# Note that these settings DBCF=CT_OLD_STYLE_LOGON_SQLCONNECT:Y DBCL=1, are used to ensure that the DBUS and PSWD are used
# and if that logon fails, a trusted connection is not attempted.
.\x_run.exe itrl=4 itrm=9999999999 itro=y  mode=b quet=y proc=*limport DBCF=CT_OLD_STYLE_LOGON_SQLCONNECT:Y DBCL=1 PROC=*WAMSP WMOD=DEPTABWA WRTN=BuildFirst WASP=c:\temp\wasp.xml
cd c:\lansa\scripts
Write-Host( "Waiting 15 seconds for log file to flush to disk")
sleep 15
if ( Test-Path -Path $logFile ) {
   cat $logFile
} else {
   Write-Host "$LogFile does not exist"
}
