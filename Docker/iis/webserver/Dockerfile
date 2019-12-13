# escape=`

# This is a temporary Docker image for speeding up development testing. Because database updates are part and parcel of installing the Webserver, it must be installed in situ, even though nothing needs to change. Potential oppourtunity to provide database import in this image so that it may be published.
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG BASE_TAG=windowsservercore-1903-14.99
FROM lansalpc/iis/base:${BASE_TAG}

# Global settings for the Container
ARG GITREPO=lansa
ARG GITREPOPATH=c:\${GITREPO}\
ARG GITBRANCH=debug/paas

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

WORKDIR c:\

COPY .\*.ps1 .\

WORKDIR ${GITREPOPATH}

ENV GITREPOPATH $GITREPOPATH

# Development-specific parameters.  This is required to install the LANSA Webserver
RUN c:\init-webserver.ps1 -server_name 'robgw10\sqls17' -dbname 'VLWEB' -dbuser 'sa' -dbpassword 'Pcxuser@122robg' -webuser 'PCXUSER2' -webpassword 'Pcxuser@122robg'

# HEALTHCHECK --interval=5s `
#  CMD powershell -command `
#     try { `
#      $response = iwr http://localhost -UseBasicParsing; `
#      if ($response.StatusCode -eq 200) { return 0} `
#      else {return 1}; `
#     } catch { return 1 }

WORKDIR c:\

ENTRYPOINT ["powershell", "C:\\bootstrap.ps1"]
