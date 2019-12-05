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

RUN  Write-Output 'Turning off complex password requirements'; `
    secedit /export /cfg 'c:\secpol.cfg'; `
    (Get-Content C:\secpol.cfg).replace('PasswordComplexity = 1', 'PasswordComplexity = 0') | Out-File C:\secpol.cfg; `
    secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY; `
    Remove-Item -force c:\secpol.cfg -confirm:$false

