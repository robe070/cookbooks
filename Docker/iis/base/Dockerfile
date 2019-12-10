# escape=`
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG WINDOWS_VERSION=windowsservercore-1903
FROM mcr.microsoft.com/windows/servercore/iis:${WINDOWS_VERSION}

# Global settings for the Container
ARG GITREPO=lansa
ARG GITREPOPATH=${GITREPO}
ARG GITBRANCH=debug/paas

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

COPY .\*.ps1 .\

RUN .\getchoco.ps1

# A new Powershell process seems to be started each time, so environment setup like dot-sourcing CommontTools needs to be done inline, not on a separate RUN instruction
RUN . '.\dot-CommonTools.ps1'; `
    .\installgit.ps1 $ENV:GitRepo $ENV:GitRepoPath $ENV:GitBranch $true

WORKDIR ${GITREPOPATH}
RUN DIR

#Verbose output is not captured in the log, so don't use it!
#RUN $VerbosePreference = 'Continue'; Write-Verbose 'Test verbose'
# Debug is.
#RUN $DebugPreference = 'Continue'; Write-Debug 'Test debug'
# Output is, and Host is.
#RUN Write-Output 'Test output'

RUN Write-Host 'Install Visual C Runtime 32-bit for VS 2015, 2017, 2019'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x86.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait;

RUN Write-Host 'Install Visual C Runtime 64-bit for VS 2015, 2017, 2019'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x64.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait

RUN Write-Host 'Install Visual C Runtime 32-bit for VS 2013'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x86_2013.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait

RUN Write-Host 'Install Visual C Runtime 64-bit for VS 2013'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x64_2013.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait

RUN  Write-Output 'Turning off complex password requirements'; `
    secedit /export /cfg 'c:\secpol.cfg'; `
    (Get-Content C:\secpol.cfg).replace('PasswordComplexity = 1', 'PasswordComplexity = 0') | Out-File C:\secpol.cfg; `
    secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY; `
    Remove-Item -force c:\secpol.cfg -confirm:$false

RUN Write-Output 'Create local user test (pwd=test)'; `
    NET USER test 'test' /ADD; `
    NET LOCALGROUP 'Administrators' 'test' /ADD

RUN .\scripts\docker-install-iis.ps1

# Currently this script just installs the PowerShell sqlps module
RUN .\scripts\install-lansa-base.ps1 'dummy' $ENV:TEMP 'dummy' 'dummy'

# configure IIS to write a global log file:
RUN Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log' -n 'centralLogFileMode' -v 'CentralW3C'; `
    Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log/centralW3CLogFile' -n 'truncateSize' -v 4294967295; `
    Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log/centralW3CLogFile' -n 'period' -v 'MaxSize'; `
    Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log/centralW3CLogFile' -n 'directory' -v 'c:\iislog'

# RUN & c:\windows\system32\inetsrv\appcmd.exe `
#       unlock config `
#       /section:system.webServer/handlers

# HEALTHCHECK --interval=5s `
#  CMD powershell -command `
#     try { `
#      $response = iwr http://localhost -UseBasicParsing; `
#      if ($response.StatusCode -eq 200) { return 0} `
#      else {return 1}; `
#     } catch { return 1 }

# Set the working directory back to the Docker default
WORKDIR c:\

ENTRYPOINT ["powershell", "C:\\bootstrap.ps1"]
