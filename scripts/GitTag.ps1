param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoName,

    [Parameter(Mandatory=$true)]
    [string[]]
    $Tags
  )

cd "$($env:System_DefaultWorkingDirectory)/$($GitRepoName)"

Write-Host( "Tagging the current HEAD")
git status

Write-Host("git tag")
foreach ($tag in $Tags) {
    Write-Host ("Tag $tag")
    git tag -f $tag
    if (-not $?) {
      Write-Host(" git tag failed");
      exit 1
    }
}

Write-Host("git push tags")
git push --tags
if (-not $?) {
  Write-Host(" git push --tags failed");
  exit 1
}