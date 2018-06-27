
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
    # Invoke-command -Session $session -ScriptBlock { $Global:LANSAEXITCODE = 0 } # Set $LASTEXITCODE to 0
    Invoke-Command -Session $session -FilePath $FilePath -ArgumentList $ArgumentList
    # Sometimes when the remote script throws, its not caught by the local catch block. Instead
    # the Session is as if its been reset. So if $LASTEXITCODE does not exist, that indicates an
    # exception has been thrown.
    # $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { 
    #     if ( Get-Variable 'LANSAEXITCODE' -Scope Global -ErrorAction 'Ignore') {
    #         Write-Host '$Global:LANSAEXITCODE value'
    #         $Global:LANSAEXITCODE 
    #     } else {
    #         Write-Host '$Global:LANSAEXITCODE does not exist'
    #         -1
    #     }
    # }
    # cmd /c exit $remotelastexitcode
    # if ( $remotelastexitcode -and $remotelastexitcode -ne 0 ) {
    #     throw "Execute-RemoteScript: LastExitCode: $remotelastexitcode"
    # }      
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

    Invoke-Command -Session $session -Scriptblock $ScriptBlock
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