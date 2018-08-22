<#
.SYNOPSIS

Pull application git repos.



.EXAMPLE

1. Upload msi to c:\lansa\MyApp.msi (Copy file from local machine. Paste into RDP session)
2. Start SQL Server Service and set to auto start. Change SQL Server to accept SQL Server Authentication
3. Create lansa database
4. Add user lansa with password 'Pcxuser@122' to SQL Server as Sysadmin and to the lansa database as dbowner
5. Change server_name to the machine name in this command line and run it:
C:\\LANSA\\scripts\\install-lansa-msi.ps1 -server_name "IP-AC1F2F2A" -dbname "lansa" -dbuser "lansa" -dbpassword "Pcxuser@122" -webuser "pcxuser" -webpassword "Lansa@122"

#>
param(
[String]$GitRepoBranch='master'
)

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

    $predeploy = Join-Path $APPA "autodeploy\predeploy.ps1"
    Write-Host( "$(Log-Date) Run $predeploy to prepare for git pull")
    & $predeploy

    Write-Host( "$(Log-Date) Stop IIS entirely so GitDeployHub may be updated")
    & iisreset /stop

    if ( [string]::IsNullOrWhiteSpace($APPA) ) {
        Write-Warning( "$(Log-Date) MainAppInstallPath registry value is non-existent or empty") | Write-Host
    } else {
        Write-Host( "$(Log-Date) Pulling Main Install Path $APPA" )

        If ( -not (Test-Path -Path $APPA) ) {
            Write-Warning( "$(Log-Date) $APPA does not exist" ) | Write-Host
        } else {
            Set-Location $APPA | Write-Host

            $gitstatus = Join-Path -Path $ENV:TEMP -ChildPath 'gitstatus.txt'
            cmd /C git status '2>&1' > $gitstatus

            $gitstatusline = Get-Content $gitstatus -First 1
            $gitstatusline | Write-Host
            if ( $gitstatusline -contains 'fatal: not a git repository' ) {
                Write-Warning( "$(Log-Date) $APPA is not a git repository" ) | Write-Host
            } else {
                Write-Host( "$(Log-Date) Pulling $APPA")

                cmd /C git pull '2>&1' | Write-Host
                if ($LASTEXITCODE -ne 0) {
                    throw ("$APPA Git pull failed")
                }
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
                Write-Warning( "$(Log-Date) $GDHPath is not a git repository. GDH is presumed to have the .git directory shipped in the MSI package.
                This requires that the build environment has the GDH repo setup. Then the MSI will
                contain it and will be installed." ) | Write-Host

                # $GDHRepoUrl = 'git@github.com:lansa/gitdeployhub.git'
                # Write-Host( "$(Log-Date) Cloning $GDHRepoUrl")

                # cmd /C git init '2>&1' | Write-Host
                # if ($LASTEXITCODE -ne 0) {
                #     throw ("$GDHPath Git init failed")
                # }

                # cmd /C git remote add origin $GDHRepoUrl '2>&1' | Write-Host
                # if ($LASTEXITCODE -ne 0) {
                #     throw ("$GDHPath Git remote add failed")
                # }

                # cmd /C git remote fetch -q '2>&1' | Write-Host
                # if ($LASTEXITCODE -ne 0) {
                #     throw ("$GDHPath Git fetch failed")
                # }

                # cmd /C git checkout -f $GitRepoBranch '2>&1' | Write-Host
                # if ($LASTEXITCODE -ne 0) {
                #     throw ("$GDHPath Git checkout failed")
                # }
            } else {

                Write-Host( "$(Log-Date) Pulling $GDHPath")

                $gitbranchfile = Join-Path -Path $ENV:TEMP -ChildPath 'gitbranch.txt'
                cmd /C git symbolic-ref -q --short HEAD '2>&1' > $gitbranchfile
                $gitbranch = Get-Content $gitbranchfile -First 1
                Write-Host( "$(Log-Date) Current branch is $gitbranch" )

                if ( $gitbranch -ne $GitRepoBranch ) {
                    Write-Host( "$(Log-Date) Checking out new branch $GitRepoBranch" )
                    cmd /C git fetch -q '2>&1' | Write-Host
                    if ($LASTEXITCODE -ne 0) {
                        throw ("$GDHPath Git fetch failed")
                    }

                    cmd /C git checkout -f $GitRepoBranch '2>&1' | Write-Host
                    if ($LASTEXITCODE -ne 0) {
                        throw ("$GDHPath Git checkout failed")
                    }
                } else {
                    cmd /C git pull '2>&1' | Write-Host
                    if ($LASTEXITCODE -ne 0) {
                        throw ("$GDHPath Git pull failed")
                    }
                }
            }
        }
    }
} catch {
    $e = $_.Exception
    $e | format-list -force

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
    & iisreset /start

    $postdeploy = Join-Path $APPA "autodeploy\postdeploy.ps1"
    Write-Host( "$(Log-Date) Run $postdeploy to put it all back online")
    & $postdeploy
 }
 Write-Host( "AppRepoPull succeeded" )
 cmd /c exit 0    #Set $LASTEXITCODE
 Write-Host( "LASTEXITCODE $LASTEXITCODE" )