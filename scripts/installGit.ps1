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

Write-Debug "GitRepo = $GitRepo"
Write-Debug "GitRepoPath = $GitRepoPath"

$Update = $false

# Git outputs almost all normal messages to stderr. powershell interprets that as an error and 
# displays the error text. To stop that stderr is redirected to stdout on the git commands.

Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

if ( $InstallGit -and (-not (Test-Path $GitRepoPath) ) )
{
    Write-Output "Installing Git"
    choco -y install git.install -version 1.9.4.20140929
    
    # Note, the Git install overwrites the current environment so need to modify path here
    Add-DirectoryToEnvPathOnce -Directory "C:\Program Files (x86)\Git\cmd"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

    cd \
    cmd /C git clone https://github.com/robe070/cookbooks.git $GitRepo '2>&1'
}
else
{
    # Make sure Git is in the path
    # Note, the Git install overwrites the current environment so need to modify path here
    Add-DirectoryToEnvPathOnce -Directory "C:\Program Files (x86)\Git\cmd"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    $Update = $true
}
Write-Output "Git installed"

Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

# Ensure we cope with an existing repo, not just a new clone...
cd $GitRepoPath
# Throw away any local changes
cmd /c git reset --hard HEAD '2>&1'
# Ensure we have all changes
cmd /c git fetch --all '2>&1'
# Check out a potentially different branch
Write-Output "Branch: $Branch"
cmd /c git checkout -f $Branch  '2>&1'
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) 
{
    Write-Error ('Git checkout failed');
    cmd /c exit $LastExitCode;
}
# Finally make sure the current branch matches the origin
cmd /c git pull '2>&1'

Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

