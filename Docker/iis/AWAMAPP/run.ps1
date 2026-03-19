$HostIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -eq 'vEthernet (nat)'}).IPAddress
docker rm -f LANSA-APP 2>$null
docker run --name LANSA-APP -it -e DEBUG=Y -e GITREPOPATH=c:\lansa -e GITBRANCH=debug/paas `
-p 50080:80 -p 54545:4545 -p 58101:8101 `
-v c:\temp:c:\temp -v c:\secrets:c:\secrets -v C:\msi:c:\msi `
-v C:\dev\cookbooks\Docker:C:\docker `
--entrypoint powershell `
lansalpc/iis-base:14.99-windowsservercore-ltsc2025 `
-NoLogo -NoProfile -ExecutionPolicy Bypass `
-File c:\docker\iis\base\init.ps1 -server_name "tcp:$HostIP,1433" -dbname 'AWAMAPP' -dbuser 'DBSetup' `
-dbpasswordpath 'c:\secrets\dbpassword.txt' -webuser 'PCXUSER2' -webpasswordpath 'c:\secrets\webpassword.txt' `
-MSIuri 'c:\msi\AWAMAPP_v16.0.26010_en-us.msi' -dbug