docker rm -f LANSA-IMG 2>$null
docker run --name LANSA-IMG -it -e DEBUG=Y `
  -p 50080:80 -p 54545:4545  `
  -v c:\temp:c:\temp `
  --entrypoint powershell `
  lansalpc/awamapp:14.99-windowsservercore-ltsc2025 `
  -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\bootstrap.ps1

