
function Execute-RemoteScript {
param (
    [Parameter(Mandatory=$true)]
    [System.Management.Automation.Runspaces.PSSession]
    $Session,

    [Parameter(Mandatory=$true)]
    [string]
    $FilePath,

    [Object[]]
    $ArgumentList
    )
<#
.SYNOPSIS

Install base LANSA requirements

.DESCRIPTION

This script calls a set of scripts to setup the base requirments of LANSA on a Windows Server.

It is intended to be run via remote PS on an AWS instance that has the LANSA Cookbooks git repository installed.

.EXAMPLE


#>
    Invoke-command -Session $session -ScriptBlock { $lastexitcode = 0}
    Invoke-Command -Session $session -FilePath $FilePath -ArgumentList $ArgumentList
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { lastexitcode$lastexitcode}
    if ( $remotelastexitcode -and $remotelastexitcode -ne 0 ) {
        throw "Execute-RemoteScript: LastExitCode: $remotelastexitcode"
    }      
}

function Execute-RemoteBlock {
param (
    [Parameter(Mandatory=$true)]
    [System.Management.Automation.Runspaces.PSSession]
    $Session,

    [Parameter(Mandatory=$true)]
    [scriptblock]
    $ScriptBlock
    )

    Invoke-command -Session $session -ScriptBlock { $lastexitcode = 0}
    Invoke-Command -Session $session -Scriptblock $ScriptBlock
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -and $remotelastexitcode -ne 0 ) {
        throw "Execute-RemoteBlock: LastExitCode: $remotelastexitcode"
    }      
}

function Execute-RemoteInit {
    Execute-RemoteBlock $Script:session {  
        $script:IncludeDir = "$using:GitRepoPath\scripts"
        Write-Debug "script:IncludeDir = $script:IncludeDir"

        $DebugPreference = $using:DebugPreference
        $VerbosePreference = $using:VerbosePreference

        # Ensure last exit code is 0. (exit by itself will terminate the remote session)
        cmd /c exit 0
    }
}

# Initialization that must wait until the git repo has been cloned so all the scripts are there.
function Execute-RemoteInitPostGit {
    Execute-RemoteBlock $Script:session { . "$script:IncludeDir\Init-Baking-Vars.ps1" | Out-Host }
    Execute-RemoteBlock $Script:session { . "$script:IncludeDir\Init-Baking-Includes.ps1" | Out-Host}
    
    Write-Output "$(Log-Date) Linking LANSA 64-bit and 32-bit registry keys" | Out-Host
    Execute-RemoteBlock $Script:session { &"$Script:IncludeDir\lansa64reginit.exe" "-f" | Out-Host}
}