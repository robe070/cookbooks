<#
.SYNOPSIS

Install base LANSA requirements

.DESCRIPTION

This script calls a set of scripts to setup the base requirments of LANSA on a Windows Server.

It is intended to be run via remote PS on an AWS instance that has the LANSA Cookbooks git repository installed.

.EXAMPLE


#>
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

    Invoke-Command -Session $session -FilePath $FilePath -ArgumentList $ArgumentList
    $remotelastexitcode = invoke-command  -Session $session -ScriptBlock { $lastexitcode}
    if ( $remotelastexitcode -and $remotelastexitcode -ne 0 ) {
        Write-Error "LastExitCode: $remotelastexitcode"
        throw 1
    }      
}