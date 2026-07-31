# escape=`

ARG BASE_IMAGE=lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025
FROM ${BASE_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

COPY ["X_PDFMS.DLL", "C:/Program Files (x86)/Docker/X_Win95/X_Lansa/Execute/X_Pdfms.dll"]
COPY ["curl-ca-bundle.crt", "C:/tools/curl-ca-bundle.crt"]

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
