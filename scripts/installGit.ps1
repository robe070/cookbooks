param (
    [Parameter(Mandatory=$true)]
    [string]
    $Branch,

    [boolean]
    $CalledUsingRemotePS = $false,

    [boolean]
    $InstallGit = $true
    )
 
# Git outputs almost all error messages to stderr. powershell interprets that as an error and 
# displays the error text. To stop that stderr is redirected to stdout on the git commands.

$env:Path += ';C:\\Program Files (x86)\\Git\\cmd'

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