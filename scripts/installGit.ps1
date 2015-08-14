param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepo,

    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath,

    [Parameter(Mandatory=$true)]
    [string]
    $Branch,

    [boolean]
    $CalledUsingRemotePS = $false,

    [boolean]
    $InstallGit = $true
    )

function Add-DirectoryToEnvPathOnce{
param (
    [string]
    $EnvVarToSet = 'PATH',

    [Parameter(Mandatory=$true)]
    [string]
    $Directory

    )

    $oldPath = [Environment]::GetEnvironmentVariable($EnvVarToSet, 'Machine')
    $match = '*' + $Directory + '*'
    $replace = $oldPath + ';' + $Directory 
    Write-Debug "OldPath = $Oldpath"
    Write-Debug "match = $match"
    Write-Debug "replace = $replace"
    if ( $oldpath -notlike $match )
    {
        [Environment]::SetEnvironmentVariable($EnvVarToSet, $replace, 'Machine')
        Write-Debug "Machine $EnvVarToSet updated"
    }

    # System Path may be different to remote PS starting environment, so check it separately
    if ( $env:Path -notlike $match )
    {
        $env:Path += ';' + $Directory
        Write-Debug "local Path updated"
    }
}

Write-Debug "GitRepo = $GitRepo"
Write-Debug "GitRepoPath = $GitRepoPath"

# Git outputs almost all normal messages to stderr. powershell interprets that as an error and 
# displays the error text. To stop that stderr is redirected to stdout on the git commands.

Add-DirectoryToEnvPathOnce -Directory "C:\Program Files (x86)\Git\cmd"

if ( $InstallGit -and (-not (Test-Path $GitRepoPath) ) )
{
    Write-Output "Installing Git"
    choco -y install git.install -version 1.9.4.20140929
    cd \
    cmd /C git clone https://github.com/robe070/cookbooks.git $GitRepo '2>&1'
}
cd $GitRepoPath
cmd /c git pull origin '2>&1'
Write-Output "Branch: $Branch"
cmd /c git checkout -f $Branch  '2>&1'
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) 
{
    Write-Error ('Git clone failed');
    cmd /c exit $LastExitCode;
}

