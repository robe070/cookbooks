# escape=`
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants

# ---- Build Arguments ----
ARG WINDOWS_REPO=mcr.microsoft.com/windows/servercore/iis
ARG WINDOWS_EDITION=windowsservercore
ARG WINDOWS_VERSION=ltsc2025
ARG WINDOWS_BASE_IMAGE=${WINDOWS_REPO}:${WINDOWS_EDITION}-${WINDOWS_VERSION}

# ---- Base Image ----
FROM ${WINDOWS_BASE_IMAGE}

# ---- Metadata Arguments (injected via CI) ----
ARG VERSION_NUM=16.0.0
ARG VERSION_LABEL="V16 GA"
ARG BUILD_DATE
ARG VCS_REF

# ---- OCI Labels ----
LABEL org.opencontainers.image.title="Visual LANSA Base Image" `
      org.opencontainers.image.description="Visual LANSA base container image for Windows" `
      org.opencontainers.image.vendor="LANSA" `
      org.opencontainers.image.version="${VERSION_NUM}" `
      org.opencontainers.image.revision="${VCS_REF}" `
      org.opencontainers.image.created="${BUILD_DATE}" `
      org.opencontainers.image.source="https://github.com/robe070/cookbooks/tree/debug/paas/Docker/iis/base" `
      org.opencontainers.image.documentation="https://github.com/robe070/cookbooks/tree/debug/paas/Docker" `
      org.opencontainers.image.licenses="Proprietary"

# ---- LANSA Labels ----
LABEL lansalpc.product="Visual LANSA" `
      lansalpc.version.numeric="${VERSION_NUM}" `
      lansalpc.version.label="${VERSION_LABEL}" `
      lansalpc.os.variant="${WINDOWS_EDITION}" `
      lansalpc.os.ltsc="${WINDOWS_VERSION}" `
      lansalpc.base.image="${WINDOWS_BASE_IMAGE}"

# Global settings for the Container
ARG GITREPO=lansa
ARG GITREPOPATH=${GITREPO}
ARG GITBRANCH=debug/paas

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

# Set the PowerShell prompt to show that we're in a container, and also ensure the profile file exists.
RUN $profileDir = Split-Path -Parent $PROFILE; ` 
    if (-not (Test-Path $profileDir)) { `
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null; `
    } `
    if (-not (Test-Path $PROFILE)) { `
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null; `
    } `
    # [char]34 is a double quote, which if used directly as " is stripped by the Docker parser. `
    Add-Content -Path $PROFILE -Value ('function prompt { ' + [char]34 + 'Cont $($executionContext.SessionState.Path.CurrentLocation)> ' + [char]34 + ' }')

ENV RUNNING_IN_CONTAINER=1

COPY .\*.ps1 .\
RUN DIR

# Curl is required to access the Cloud Metadata
# RUN .\installcurl.ps1

RUN . '.\dot-CommonTools.ps1'; `
    .\getchoco.ps1

# A new Powershell process seems to be started each time, so environment setup like dot-sourcing CommontTools needs to be done inline, not on a separate RUN instruction
RUN . '.\dot-CommonTools.ps1'; `
    .\installgit.ps1 -gitrepo $ENV:GitRepo -gitrepopath $ENV:GitRepoPath -branch $ENV:GitBranch -GitUserName 'robe070'

WORKDIR ${GITREPOPATH}
RUN DIR

#Verbose output is not captured in the log, so don't use it!
#RUN $VerbosePreference = 'Continue'; Write-Verbose 'Test verbose'

RUN Write-Host 'Install Visual C Runtime 32-bit for VS 2015, 2017, 2019'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x86.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait;

RUN Write-Host 'Install Visual C Runtime 64-bit for VS 2015, 2017, 2019'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x64.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait

RUN Write-Host 'Install Visual C Runtime 32-bit for VS 2013'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x86_2013.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait

RUN Write-Host 'Install Visual C Runtime 64-bit for VS 2013'; `
    start-process -FilePath '.\installs\vc_redist\vcredist_x64_2013.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait

RUN .\scripts\docker-install-iis.ps1

# Currently this script just installs the PowerShell sqlps module
RUN .\scripts\install-lansa-base.ps1 'dummy' $ENV:TEMP 'dummy' 'dummy'

# configure IIS to write a global log file:
RUN Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log' -n 'centralLogFileMode' -v 'CentralW3C'; `
    Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log/centralW3CLogFile' -n 'truncateSize' -v 4294967295; `
    Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log/centralW3CLogFile' -n 'period' -v 'MaxSize'; `
    Set-WebConfigurationProperty -p 'MACHINE/WEBROOT/APPHOST' -fi 'system.applicationHost/log/centralW3CLogFile' -n 'directory' -v 'c:\iislog'

# Set the working directory back to the Docker default
WORKDIR c:\

ENTRYPOINT ["powershell", "C:\\bootstrap.ps1"]
