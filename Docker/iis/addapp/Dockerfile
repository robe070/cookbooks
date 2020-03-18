# escape=`
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG BASE_TAG=14.99-windowsservercore-1903
FROM lansalpc/iis/webserver:${BASE_TAG}

# Global settings for the Building of the Container
ARG GITREPO=lansa
ARG GITREPOPATH=c:\${GITREPO}\
ARG GITBRANCH=debug/paas
ARG GITREPOURL="git@github.com:lansa/lansaeval301.git"

EXPOSE 4545

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

WORKDIR c:\

COPY .\* .\

WORKDIR ${GITREPOPATH}

# CMD parameter default values
# Note how ARG variables need to be reflected into ENV variables to persist them in the running container
ENV GITREPOPATH=$GITREPOPATH `
    GITREPOURL=$GITREPOURL `
    GITBRANCH=$GITBRANCH `
    SSHKEYPATH="c:\secrets\ssh-key" `
    SERVERNAME="robgw10\sqls17" `
    DBNAME="VLWEB" `
    DBUSER="sa" `
    DBPASSWORD="Pcxuser@122robg" `
    DBPASSWORDPATH="c:\secrets\db-password" `
    WEBUSER="PCXUSER2" `
    WEBPASSWORD="Pcxuser@122robg" `
    WEBPASSWORDPATH="c:\secrets\web-password"

# ...and ssh key in container's c:\temp\id_rsa
# ...and msi in c:\temp\lansa.msi

ENTRYPOINT ["powershell"]

EXPOSE 4545

# Default COMMAND parameters.  This is required to install the LANSA MSI
# Note that the MSIuri parameter will work with local paths or an S3 url. And any uri that delivers an MSI as a file.
# The default value for MSIuri is not set on the command line by default as its in the TEMP directory which is changed in the script.

CMD c:\init-paas.ps1 -server_name $ENV:SERVERNAME -dbname $ENV:DBNAME -dbuser $ENV:DBUSER -dbpassword $ENV:DBPASSWORD -dbpasswordpath $ENV:DBPASSWORDPATH -webuser $ENV:WEBUSER -webpassword $ENV:WEBPASSWORD -webpasswordpath $ENV:WEBPASSWORDPATH -sshkeypath $ENV:SSHKEYPATH -GitRepoUrl $ENV:GITREPOURL -GitBranch $ENV:GITBRANCH -MSIuri $ENV:MSIuri -dbug

# HEALTHCHECK --interval=5s `
#  CMD powershell -command `
#     try { `
#      $response = iwr http://localhost -UseBasicParsing; `
#      if ($response.StatusCode -eq 200) { return 0} `
#      else {return 1}; `
#     } catch { return 1 }

WORKDIR c:\