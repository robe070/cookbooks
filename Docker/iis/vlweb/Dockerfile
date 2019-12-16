# escape=`
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG BASE_TAG=windowsservercore-1903-14.99
FROM lansalpc/iis/webserver:${BASE_TAG}

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

ENTRYPOINT ["powershell"]

# Example COMMAND parameters.  This is required to install the LANSA MSI
# So without this on the docker run command line, there will be an error when the database is accessed
CMD c:\init.ps1 -server_name 'mypc\sqls17' -dbname 'VLWEB' -dbuser 'sa' -dbpassword 'dbpassword' -webuser 'webuser' -webpassword 'webpassword' -MSIuri 'c:\vlweb.msi'

# HEALTHCHECK --interval=5s `
#  CMD powershell -command `
#     try { `
#      $response = iwr http://localhost -UseBasicParsing; `
#      if ($response.StatusCode -eq 200) { return 0} `
#      else {return 1}; `
#     } catch { return 1 }

WORKDIR c:\