# escape=`

# This is a temporary Docker image for speeding up development testing. Because database updates are part and parcel of installing the Webserver, it must be installed in situ, even though nothing needs to change. Potential oppourtunity to provide database import in this image so that it may be published.
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG BASE_TAG=16.0.0-ltsc2025
FROM lansalpc/vlbase-servercore:${BASE_TAG}

# Global settings for the Container
ARG GITREPO=lansa
ARG GITREPOPATH=c:\${GITREPO}\
ARG GITBRANCH=debug/paas
#ARG GITBRANCH=support/L4W14200_paas

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

WORKDIR c:\

COPY .\*.ps1 .\

WORKDIR ${GITREPOPATH}

ENV GITREPOPATH $GITREPOPATH
ENV GITBRANCH $GITBRANCH

EXPOSE 80
EXPOSE 8101

# Create license directory
RUN "New-Item -ItemType Directory -Path 'C:\Program Files (x86)\Common Files\LANSA' -Force | Out-Null"


# Copy license files into the image.
# Using JSON array form so that the folder delimiting backslashes are not treated as escape characters.  
# Also the space in the path causes issues too.
COPY ["*.lic", "C:/Program Files (x86)/Common Files/LANSA/"]

# Create registry key and set LicenseDir
RUN "New-Item -Path 'HKLM:\SOFTWARE\LANSA\COMMON' -Force | Out-Null; " `
    "Set-ItemProperty -Path 'HKLM:\SOFTWARE\LANSA\COMMON' -Name 'LicenseDir' -Value 'C:\Program Files (x86)\Common Files\LANSA';" `
    "Set-ItemProperty -Path 'HKLM:\SOFTWARE\LANSA' -Name 'Cloud' -Value 'Azure';"

# Development-specific parameters.  This is required to install the LANSA Webserver
RUN c:\init-webserver.ps1 -server_name 'tcp:host.docker.internal,1433' -dbname 'webserver-docker' -dbuser 'DBSetup' -dbpassword 'Pcxuser@122robg' -webuser 'PCXUSER2' -webpassword 'Pcxuser@122robg' -GitBranch $ENV:GITBRANCH -GitBranchWebserver $ENV:GITBRANCH

# HEALTHCHECK --interval=5s `
#  CMD powershell -command `
#     try { `
#      $response = iwr http://localhost -UseBasicParsing; `
#      if ($response.StatusCode -eq 200) { return 0} `
#      else {return 1}; `
#     } catch { return 1 }

WORKDIR c:\

ENTRYPOINT ["powershell", "C:\\bootstrap.ps1"]
