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

    [Parameter(Mandatory=$true)]
    [string]
    $GitUserName,

    [boolean]
    $CalledUsingRemotePS = $false,

    [boolean]
    $InstallGit = $true
    )

Write-Debug "GitRepo = $GitRepo" | Out-Host
Write-Debug "GitRepoPath = $GitRepoPath" | Out-Host

$Update = $false

try {
    # Git outputs almost all normal messages to stderr. powershell interprets that as an error and 
    # displays the error text. To stop that stderr is redirected to stdout on the git commands.

    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host

    if ( $InstallGit -and (-not (Test-Path $GitRepoPath) ) )
    {
        Write-Output "Installing Git" | Out-Host
        Run-ExitCode 'choco' @('install', 'git', '-y', '--no-progress', '--force' ) | Out-Host
        refreshenv | Out-Host

        # Note, the Git install overwrites the current environment so need to modify path here
        Add-DirectoryToEnvPathOnce -Directory "C:\Program Files\Git\cmd" | Out-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host

        Set-Location \ | Out-Host
        # cmd /C git clone https://github.com/robe070/cookbooks.git $GitRepo '2>&1'
        Run-ExitCode 'git' @('clone', "https://github.com/$GitUserName/cookbooks.git", $GitRepo) | Out-Host
    }
    else
    {
        # Make sure Git is in the path
        # Note, the Git install overwrites the current environment so need to modify path here
        Add-DirectoryToEnvPathOnce -Directory "C:\Program Files\Git\cmd" | Out-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
        $Update = $true
    }
    Write-Output "Git installed" | Out-Host

    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host

    # Ensure we cope with an existing repo, not just a new clone...
    Set-Location $GitRepoPath | Out-Host
    # Throw away any local changes
    cmd /c git reset --hard HEAD '2>&1' | Out-Host
    # Ensure we have all changes
    cmd /c git fetch --all '2>&1' | Out-Host
    # Check out a potentially different branch
    Write-Output "Branch: $Branch" | Out-Host
    cmd /c git checkout -f $Branch  '2>&1' | Out-Host
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) 
    {
        cmd /c exit $LastExitCode;
        throw 'Git checkout failed'
    }
    # Finally make sure the current branch matches the origin
    cmd /c git pull '2>&1' | Out-Host

    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
} catch {
    $_
    Write-Host "installGit.ps1 is the <No file> in the stack dump below"
    $PSItem.ScriptStackTrace | Out-Host
    if ( $LASTEXITCODE -eq 0 ) {
        cmd /c exit 1
    }
    return
}
