param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath,

    [Parameter(Mandatory=$true)]
    [string]
    $GitSourceBranch,

    [Parameter(Mandatory=$true)]
    [string]
    $GitTargetBranch
  )

function ExecuteGitCommand {
  param (
    [Parameter(Mandatory=$true)]
    [string[]]
    $GitCommandLine
  )

  & git $gitCommandLine
  if (-not $?) {
    throw("git $gitCommandLine failed");
  }
}

Push-Location

try {
  if ( $($env:Pipeline_Workspace) -eq "") {
    Write-Host "Changing directory to '$($env:Pipeline_Workspace)/$GitRepoPath'"
    cd "$($env:Pipeline_Workspace)/$GitRepoPath"
  } else {
    Write-Host "Changing directory to '$GitRepoPath'"
    cd $GitRepoPath
  }

  ExecuteGitCommand( "checkout", $GitSourceBranch)
  ExecuteGitCommand( "pull", "origin", $GitSourceBranch)

  ExecuteGitCommand( "checkout", $GitTargetBranch)
  ExecuteGitCommand( "pull", "origin", $GitTargetBranch)

  # merge changes from source branch
  ExecuteGitCommand( "merge", $GitSourceBranch)

  # push changes from target branch
  ExecuteGitCommand( "push", "origin", $GitTargetBranch)
} catch {
  Write-Error $_.Exception.Message
} finally {
  Pop-Location
}