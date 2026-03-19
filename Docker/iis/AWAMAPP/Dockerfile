# escape=`

# This is a temporary Docker image for speeding up development testing. Because database updates are part and parcel of installing the Webserver, it must be installed in situ, even though nothing needs to change. Potential oppourtunity to provide database import in this image so that it may be published.
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG BASE_TAG=14.99-windowsservercore-ltsc2025
FROM lansalpc/iis-base:${BASE_TAG} as build

# Global settings for the Container
ARG HOST_IP=tcp:host.docker.internal
ARG GITREPO=lansa
ARG GITREPOPATH=c:\${GITREPO}\
ARG GITBRANCH=debug/paas
#ARG GITBRANCH=support/L4W14200_paas

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

WORKDIR c:\

COPY .\*.ps1 .\

WORKDIR ${GITREPOPATH}

ENV APPLNAME="Docker" `
    MSIURI="c:\msi\AWAMAPP_v16.0.26010_en-us.msi" `
    GITREPOPATH=$GITREPOPATH `
    GITBRANCH=$GITBRANCH `
    SERVERNAME="$HOST_IP,1433" `
    DBNAME="AWAMAPP" `
    DBUSER="DBSetup" `
    DBPASSWORDPATH="c:\secrets\dbpassword.txt" `
    WEBUSER="PCXUSER2" `
    WEBPASSWORDPATH="c:\secrets\webpassword.txt" `
    DEBUG=N `
    SUDB=1

EXPOSE 80
EXPOSE 8101

# Create license directory
RUN "New-Item -ItemType Directory -Path 'C:\Program Files (x86)\Common Files\LANSA' -Force | Out-Null"

# Copy license files into the image.
# Using JSON array form so that the folder delimiting backslashes are not treated as escape characters.  
# Also the space in the path causes issues too.
COPY ["*.lic", "C:/Program Files (x86)/Common Files/LANSA/"]

# Create secrets directory
RUN "New-Item -ItemType Directory -Path 'C:/secrets' -Force | Out-Null"

# Copy secrets
COPY ["c:/secrets/*.txt", "C:/secrets/"]

# Create registry key and set LicenseDir
RUN "New-Item -Path 'HKLM:\SOFTWARE\LANSA\COMMON' -Force | Out-Null; " `
    "Set-ItemProperty -Path 'HKLM:\SOFTWARE\LANSA\COMMON' -Name 'LicenseDir' -Value 'C:\Program Files (x86)\Common Files\LANSA';" `
    "Set-ItemProperty -Path 'HKLM:\SOFTWARE\LANSA' -Name 'Cloud' -Value 'Azure';"

# Development-specific parameters.  This is required to install the LANSA Webserver
# *********** What do we call to install AWAMAPP? ************
# Deal with secrets and licenses correctly for production app.
# Map all log files into host volumes for easy access. And also for persistence if the Container is re-created. 
# This is important for the database logs as well as the webserver logs.
# ************************************************************
RUN c:\init.ps1 -server_name $ENV:SERVERNAME -dbname $ENV:DBNAME -dbuser $ENV:DBUSER -dbpasswordpath $ENV:DBPASSWORDPATH -webuser $ENV:WEBUSER -webpasswordpath $ENV:WEBPASSWORDPATH -MSIuri $ENV:MSIuri -dbug

WORKDIR c:\

ENTRYPOINT ["powershell", "C:\\bootstrap.ps1"]

# Debug stage to inspect
FROM build AS debug
CMD ["powershell.exe", "-NoLogo", "-NoExit"]