Write-Host("Committing the LANSA App and replacing the installation script with c:\bootstrap.ps1")
docker commit `
  --change 'ENTRYPOINT ["powershell","-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File","C:\\bootstrap.ps1"]' `
  --change 'CMD []' `
  LANSA-APP lansalpc/awamapp:14.99-windowsservercore-ltsc2025
