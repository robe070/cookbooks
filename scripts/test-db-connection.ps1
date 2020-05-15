cd C:\temp\cookbooks\scripts
 . .\dot-DBTools.ps1
Import-Module "sqlps" -DisableNameChecking | Out-Null
c:
Create-SqlServerDatabase '<ip address>,1433' 'Rob2' 'admin' 'Pcxuser@122robg'