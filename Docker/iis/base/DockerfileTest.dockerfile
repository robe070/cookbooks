# escape=`
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG WINDOWS_VERSION=windowsservercore-1909
FROM mcr.microsoft.com/windows/servercore/iis:${WINDOWS_VERSION}

# Global settings for the Container
ARG GITREPO=lansa
ARG GITREPOPATH=${GITREPO}
ARG GITBRANCH=debug/paas

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

COPY .\*.ps1 .\
COPY .\*.exe .\


RUN reg add HKEY_LOCAL_MACHINE\Software\WOW6432Node\LANSA; `
    reg query HKEY_LOCAL_MACHINE\Software\WOW6432Node\LANSA; `
    .\x64SoftwareKeyLink.exe LANSA; `
    reg query HKEY_LOCAL_MACHINE\Software\LANSA
