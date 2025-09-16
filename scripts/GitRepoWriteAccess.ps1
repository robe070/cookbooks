param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitBranch,

    # eg: GitURL you can get it from github repo (i.e. clone https url)
    # to generate parsonal access token please follow steps mentioned in below url
    # https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token
    # eg format for gitURL https://<Personal access token>:x-auth-basic@github.com/lansa/aws-templates.git
    [Parameter(Mandatory=$true)]
    [string]
    $GitURL,

    [Parameter(Mandatory=$true)]
    [string]
    $GitUserEmail,

    [Parameter(Mandatory=$true)]
    [string]
    $GitUserName,

    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath
  )

# goto git repo
cd "$($env:Pipeline_Workspace)/$($GitRepoPath)"

# Comment out this code as we are using the checkout step to get the correct branch.
# Doing the checkout here means we regress the scripts to a potentially older version in the target branch, whereas we need the latest of the source branch
# git checkout to branch
# git checkout $GitBranch
# if (-not $?) {
#   Write-Host("git checkout $GitBranch failed");
#   exit 1
# }

Write-Host "Configuring git email '$GitUserEmail'"
git config --global user.email "$GitUserEmail"
if (-not $?) {
  Write-Host("git config --global user.email failed");
  exit 1
}

Write-Host "Configuring git email '$GitUserName'"
git config --global user.name "$GitUserName"
if (-not $?) {
  Write-Host("git config --global user.name failed");
  exit 1
}

# git set remote origin url with personal access token
Write-Host "Configuring remote url '$GitURL'"
git remote set-url origin $GitURL
if (-not $?) {
  Write-Host("git remote set-url failed");
  exit 1
}
