param (
    [Parameter(Mandatory=$true)]
    [string]
    $Branch,

    [boolean]
    $CalledUsingRemotePS = $false,

    [boolean]
    $InstallGit = $true
    )

# Includes
if ( -not $script:IncludeDir)
{
    $script:IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path
}
. "$Script:IncludeDir\dot-Add-DirectoryToEnvPathOnce.ps1"

# Git outputs almost all normal messages to stderr. powershell interprets that as an error and 
# displays the error text. To stop that stderr is redirected to stdout on the git commands.

Add-DirectoryToEnvPathOnce -Directory "C:\Program Files (x86)\Git\cmd"

if ( $InstallGit )
{
    Write-Output "Installing Git"
    choco -y install git.install -version 1.9.4.20140929
    cd \
    cmd /C git clone https://github.com/robe070/cookbooks.git lansa '2>&1'
}
cd \lansa
cmd /c git pull origin
Write-Output "Branch: $Branch"
cmd /c git checkout -f $Branch  '2>&1'
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) 
{
    Write-Error ('Git clone failed');
    if ( -not $CalledUsingRemotePS )
    {
        exit $LastExitCode;
    }
}