<#
.SYNOPSIS

Pull application git repos.

Presumes the repos are already setup.

There may be 2 repos:
1) The application repo whose location is found in the registry entry MainAppInstallPath
2) A possible sub repo in [root]\tools\GitDeployHub

Both repos use the same branch.

The application directory must exist, otherwise its a fatal error. If the application repo does not exist, its a fatal.
The GDH directory is optional, if not a warning is displayed. If it exists but the git repo does not, its a fatal.

.EXAMPLE

#>
param(
[String]$GitRepoBranch='master'
)

function Checkout-GitRepo
{
    param (
        [Parameter(Mandatory=$true)]
            [string]
            $RepoPath,

        [Parameter(Mandatory=$true)]
            [String]
            $GitRepoBranch,

        [Parameter(Mandatory=$true)]
            [boolean]
            $IgnoreError

    )

    Write-Host( "$(Log-Date) Checking out $RepoPath branch $GitRepoBranch")
    Set-Location $RepoPath | Write-Host

    $gitbranchfile = Join-Path -Path $ENV:TEMP -ChildPath 'gitbranch.txt'
    cmd /C git symbolic-ref -q --short HEAD '2>&1' > $gitbranchfile
    $gitcurrentbranch = Get-Content $gitbranchfile -First 1
    Write-Host( "$(Log-Date) Current branch is $gitcurrentbranch" )

    if ( $gitcurrentbranch -ne $GitRepoBranch ) {
        Write-Host( "$(Log-Date) Checking out new branch $GitRepoBranch" )
        cmd /C git fetch -q '2>&1' | Write-Host
        if ($LASTEXITCODE -ne 0) {
            throw ("$RepoPath Git fetch failed")
        }

        cmd /C git checkout -f $GitRepoBranch '2>&1' | Write-Host
        if ($LASTEXITCODE -ne 0) {
            if ( $IgnoreError ) {
                Write-Warning ("$RepoPath Git checkout failed, continuing because this is expected, before running pre-deploy.ps1 which may have been updated by this checkout") | Write-Host
            } else {
                throw ("$RepoPath Git checkout failed")
            }
        }
    } else {
        cmd /C git pull '2>&1' | Write-Host
        if ($LASTEXITCODE -ne 0) {
            if ( $IgnoreError ) {
                Write-Warning ("$RepoPath Git pull failed, continuing because this is expected, before running pre-deploy.ps1 which may have been updated by this pull") | Write-Host
            } else {
                throw ("$RepoPath Git pull failed")
            }
        }
    }
}

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

Write-Host "$(Log-Date) Pulling application repos"

Write-Host("$(Log-Date) Script Directory: $script:IncludeDir")

cmd /c exit 0    #Set $LASTEXITCODE

try {
    $APPA = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'MainAppInstallPath' -ErrorAction SilentlyContinue).MainAppInstallPath

    # Clean up what we may need to restore in case there is an exception before the new config is saved.
    $GDHSaveConfig = Join-Path $Env:temp 'Web.config'
    Remove-Item $GDHSaveConfig -Force -ErrorAction SilentlyContinue | Write-Host

    if ( [string]::IsNullOrWhiteSpace($APPA) ) {
        throw "MainAppInstallPath registry value is non-existent or empty"
    } else {
        Write-Host( "$(Log-Date) Pulling Main Install Path $APPA" )

        If ( -not (Test-Path -Path $APPA) ) {
            throw "$APPA does not exist"
        } else {
            Set-Location $APPA | Write-Host

            Write-Host( "Current location $(Get-Location)") | Write-Host

            $gitstatus = Join-Path -Path $ENV:TEMP -ChildPath 'gitstatus.txt'
            cmd /C git status '2>&1' > $gitstatus

            $gitstatusline = Get-Content $gitstatus -First 1
            $gitstatusline | Write-Host
            if ( $gitstatusline -contains 'fatal: not a git repository' ) {
                throw "$APPA is not a git repository"
            } else {
                Write-Host( "$(Log-Date) Checkout whatever can be updated, especially scripts needed for this install")
                Checkout-GitRepo -RepoPath $APPA -GitRepoBranch $GitRepoBranch -IgnoreError $true
            }
        }

        $GDHPath = Join-Path -Path $APPA -ChildPath 'Tools\GitDeployHub'
        Write-Host( "$(Log-Date) Pulling GitDeployHub Path $GDHPath" )

        If ( -not (Test-Path -Path $GDHPath) ) {
            Write-Warning( "$(Log-Date) $GDHPath does not exist" ) | Write-Host
        } else {
            Set-Location $GDHPath | Write-Host

            $gitdir = Join-Path -Path $GDHPath -ChildPath '.git'
            If ( -not (Test-Path -Path $gitdir) ) {
                throw "$GDHPath is not a git repository"
            } else {
                $GDHConfig = Join-Path $GDHPath 'Web\Web.config'
                Write-Host( "$(Log-Date) Save GDH Configuration $GDHConfig to $GDHSaveConfig")
                copy-item -Path $GDHConfig -Destination $GDHSaveConfig -Force | Write-Host

                Write-Host( "$(Log-Date) Checkout whatever can be updated, especially scripts needed for this install")
                Checkout-GitRepo -RepoPath $GDHPath -GitRepoBranch $GitRepoBranch  -IgnoreError $true
            }
        }
    }

    $predeploy = Join-Path $APPA "autodeploy\predeploy.ps1"
    Write-Host( "$(Log-Date) Run $predeploy to prepare for git pull")
    & $predeploy

    Write-Host( "$(Log-Date) Stop IIS entirely so GitDeployHub may be updated")
    & iisreset /stop

    Write-Host( "$(Log-Date) Perform full checkout now that everything has been stopped")

    Checkout-GitRepo -RepoPath $APPA -GitRepoBranch $GitRepoBranch -IgnoreError $false
    Checkout-GitRepo -RepoPath $GDHPath -GitRepoBranch $GitRepoBranch  -IgnoreError $false
} catch {
    $_ | Write-Host
    $e = $_.Exception
    $e | format-list -force | Write-Host

    Write-Host( "AppRepoPull failed" )
    Write-Host( "Raw LASTEXITCODE $LASTEXITCODE" )
    if ( ( -not [ string ]::IsNullOrWhiteSpace( $LASTEXITCODE ) ) -and ( $LASTEXITCODE -ne 0 ) )
    {
       $ExitCode = $LASTEXITCODE
       Write-Host( "ExitCode set to LASTEXITCODE $ExitCode" )
    } else {
       $ExitCode = $e.HResult
       Write-Host( "ExitCode set to HResult $ExitCode" )
    }

    if ( $null -eq $ExitCode -or $ExitCode -eq 0 )
    {
       $ExitCode = -1
       Write-Host( "ExitCode set to $ExitCode" )
    }
    Write-Host( "Final ExitCode $ExitCode" )
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    Write-Host( "Final LASTEXITCODE $LASTEXITCODE" )
    return
 } finally {
    $SAVEDLASTEXITCODE = $null
    if ( ( -not [ string ]::IsNullOrWhiteSpace( $LASTEXITCODE ) ) -and ( $LASTEXITCODE -ne 0 ) )
    {
         $SAVEDLASTEXITCODE = $LASTEXITCODE
    }

    if ( Test-Path $GDHSaveConfig ) {
        Write-Host( "$(Log-Date) Restore GDH Configuration from $GDHSaveConfig to $GDHConfig")
        copy-item -Path $GDHSaveConfig -Destination $GDHConfig -Force | Write-Host
        Remove-Item $GDHSaveConfig -Force -ErrorAction Continue | Write-Host
    }

    & iisreset /start

    $postdeploy = Join-Path $APPA "autodeploy\postdeploy.ps1"
    Write-Host( "$(Log-Date) Run $postdeploy to put it all back online")
    & $postdeploy
    if ( $null -ne $SAVEDLASTEXITCODE ) {
        cmd /c exit $SAVEDLASTEXITCODE
    }
 }
 Write-Host( "AppRepoPull succeeded" )
 cmd /c exit 0    #Set $LASTEXITCODE
 Write-Host( "LASTEXITCODE $LASTEXITCODE" )