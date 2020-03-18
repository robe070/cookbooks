# escape=`
# Allow this Dockerfile to be called multiple times with different base OS as there will need to be multiple constructed to support all the Windows OS variants
ARG BASE_TAG=14.99-windowsservercore-1909
FROM lansalpc/iis/base:${BASE_TAG}

# Global settings for the Building of the Container

# Git repo used to build the container
ARG GITREPO=lansa
ARG GITREPOPATH=c:\${GITREPO}\
ARG GITBRANCH=debug/paas

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

WORKDIR c:\

COPY .\* .\

WORKDIR ${GITREPOPATH}

# CMD parameter default values
# Note how ARG variables need to be reflected into ENV variables to persist them in the running container
# And most parameters are expected to be passed as environment variables, unless they are secrets
# Secrets are stored in files. Map a host volume into the Container and then refer to that context from the environment variables
# listed below. The envirionment variables like DBPASSWORD are NOT to be used for production systems. Its not as secure.
# APPLNAME needs to match the application name IN the MSI as its used to retrieve the application git repo settings from the registry.
# That is, its the name of the application built in the Deployment Tool. And by default LANSA provide an MSI install called
# DOCKER_v1.0.0_en-us.msi. Thus APPLNAME=Docker.
# Its quite useful when developing a Container to use a host volume to pass the MSI build location and then refer to that volume mapping
# in the MSIURI environment variable, like this:
# -v C:\progra~1\lansa\X_WIN95\X_LANSA\X_APPS\DOCKER:c:\msi -e MSIURI=c:\msi\DOCKER_v1.0.0_en-us.msi
# Thus the MSI may be built and the container constructed without needing to copy the MSI to a separate location.

ENV APPLNAME="Docker" `
    GITREPOPATH=$GITREPOPATH `
    GITBRANCH=$GITBRANCH `
    GITAPPURL="git@github.com:lansa/lansaeval301.git" `
    GITAPPBRANCH="master" `
    SSHKEYPATH="c:\secrets\ssh-key" `
    SERVERNAME="database server name" `
    DBNAME="VLWEB" `
    DBUSER="sa" `
    DBPASSWORD="password" `
    DBPASSWORDPATH="c:\secrets\db-password.txt" `
    WEBUSER="PCXUSER2" `
    WEBPASSWORD="password" `
    WEBPASSWORDPATH="c:\secrets\web-password.txt"

# ...and ssh key in container's c:\temp\id_rsa

ENTRYPOINT ["powershell"]

EXPOSE 80
EXPOSE 8101
EXPOSE 4545

# Default COMMAND parameters.  This is required to install the LANSA MSI
# Note that the MSIuri parameter will work with local paths or an S3 url. And any uri that delivers an MSI as a file.
# The default value for MSIuri is not set on the command line by default as its in the TEMP directory which is changed in the script.

CMD c:\init-paas.ps1 -ApplName $ENV:APPLNAME -server_name $ENV:SERVERNAME -dbname $ENV:DBNAME -dbuser $ENV:DBUSER -dbpassword $ENV:DBPASSWORD -dbpasswordpath $ENV:DBPASSWORDPATH -webuser $ENV:WEBUSER -webpassword $ENV:WEBPASSWORD -webpasswordpath $ENV:WEBPASSWORDPATH -sshkeypath $ENV:SSHKEYPATH -GitAppUrl $ENV:GITAPPURL -GitAppBranch $ENV:GITAPPBRANCH -GitBranch $ENV:GITBRANCH -MSIuri $ENV:MSIuri -dbug

# HEALTHCHECK --interval=5s `
#  CMD powershell -command `
#     try { `
#      $response = iwr http://localhost -UseBasicParsing; `
#      if ($response.StatusCode -eq 200) { return 0} `
#      else {return 1}; `
#     } catch { return 1 }

WORKDIR c:\