<#
.SYNOPSIS
    Updates a single variable in an Azure DevOps Library variable group via the
    distributedtask REST API. Dry-run by default; only writes with -Submit.

    Written to replace the manual "increment the variable in the SKU Versions group"
    instruction in the Post Successful Live Test Gate of "Azure Publish Images.yaml".

.DESCRIPTION
    Two ways to supply the value:

      -Value <string>        an explicit value.

      -ArtefactsPath <dir>   DERIVE the value from the image artefacts the run tested.
                             This is the intended mode for PublishedVersionText: the
                             value is not "the old value + 1", it is the VersionText of
                             the _BuildImageReleaseArtefacts build that this run has just
                             finished testing. Each built plan drops a
                             <dir>/<plan>/<plan>.txt holding its gallery image-version
                             resource id (same layout azure_set_gate_variable.ps1 reads):

                               .../galleries/LansaGallery/images/w25d-16-0/versions/16.0.23
                                                                                     ^^
                             The third part of <x.y.z> IS the VersionText. Every artefact
                             in a run is built from one VersionText, so all plans must
                             agree - a disagreement means the artefacts are mixed and the
                             script fails rather than picking one.

    WHY REST AND NOT THE az CLI: the Default agents are provisioned with Az PowerShell and
    the AWS CLI but NOT the Azure CLI (see 'create agents.yml'), and Az PowerShell has no
    Azure DevOps cmdlets - Az.* is Resource Manager only. Invoke-RestMethod needs nothing
    that is not already there, and matches the other tooling scripts in this folder.

    WHOLE-GROUP UPDATE: the API has no per-variable operation. The only write is
    PUT .../variablegroups/{groupId}, which REPLACES the group. (This is equally true of
    'az pipelines variable-group variable update' - it read-modify-writes internally.) So
    this GETs the group, changes the one variable in place, and PUTs the object back with
    everything else untouched. Consequence: any SECRET variable in the group is returned by
    the GET without its value, and round-tripping it risks clearing it. The script refuses
    to write a group containing secrets unless -AllowSecrets is given.

    Auth: -AccessToken, else SYSTEM_ACCESSTOKEN, else AZURE_DEVOPS_EXT_PAT. In a pipeline
    map System.AccessToken through the step's env: block. The identity needs
    **Administrator** on the variable group - User is read-only and the PUT returns 403.

    A value changed mid-run is NOT guaranteed to be seen by later stages of the same run.
    Treat this as setting up the NEXT run.

.PARAMETER VariableGroupName  Library group holding the variable (default 'SKU Versions').
.PARAMETER VariableName       Variable to set (default 'PublishedVersionText').
.PARAMETER Value              Explicit value. Mutually exclusive with -ArtefactsPath.
.PARAMETER ArtefactsPath      Downloaded _BuildImageReleaseArtefacts root; derives the value.
.PARAMETER Organization       Azure DevOps org URL. Defaults to the agent's collection URI.
.PARAMETER Project            Team project. Defaults to the agent's project.
.PARAMETER ProjectId          Project GUID. Defaults to the agent's, else looked up.
.PARAMETER AccessToken        PAT or System.AccessToken. Defaults to the env vars above.
.PARAMETER AllowSecrets       Permit the PUT even though the group contains secret variables.
.PARAMETER Submit             Actually write. Without it the script only reports.

.EXAMPLE
    # Dry run - show what PublishedVersionText would become, derived from the tested artefacts
    .\Update-LibraryVariable.ps1 -ArtefactsPath "$(Pipeline.Workspace)/_BuildImageReleaseArtefacts"

.EXAMPLE
    # Explicit value, run locally against a PAT
    $env:AZURE_DEVOPS_EXT_PAT = '<pat>'
    .\Update-LibraryVariable.ps1 -Organization https://dev.azure.com/VisualLansa `
        -Project 'Lansa Azure Scalable License Images' -Value 23 -Submit
#>
[CmdletBinding(DefaultParameterSetName = 'FromArtefacts')]
param(
    [string] $VariableGroupName = 'SKU Versions',
    [string] $VariableName      = 'PublishedVersionText',

    [Parameter(Mandatory, ParameterSetName = 'ExplicitValue')]
    [string] $Value,

    [Parameter(ParameterSetName = 'FromArtefacts')]
    [string] $ArtefactsPath = "$env:PIPELINE_WORKSPACE/_BuildImageReleaseArtefacts",

    [string] $Organization,
    [string] $Project,
    [string] $ProjectId,
    [string] $AccessToken,
    [switch] $AllowSecrets,
    [switch] $Submit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ApiVersion = '7.1'

# --- Where to talk to -------------------------------------------------------
# On an agent these come for free; locally they must be supplied.
if (-not $Organization) { $Organization = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI }
if (-not $Project)      { $Project      = $env:SYSTEM_TEAMPROJECT }
if (-not $ProjectId)    { $ProjectId    = $env:SYSTEM_TEAMPROJECTID }
if (-not $Organization) { throw "-Organization is required when not running on an agent (e.g. https://dev.azure.com/VisualLansa)." }
if (-not $Project)      { throw "-Project is required when not running on an agent (e.g. 'Lansa Azure Scalable License Images')." }
$Organization = $Organization.TrimEnd('/')

if (-not $AccessToken) { $AccessToken = $env:SYSTEM_ACCESSTOKEN }
if (-not $AccessToken) { $AccessToken = $env:AZURE_DEVOPS_EXT_PAT }
if (-not $AccessToken) { throw "No credential. Pass -AccessToken, or set SYSTEM_ACCESSTOKEN / AZURE_DEVOPS_EXT_PAT." }

# System.AccessToken is a JWT and must be sent as a Bearer token; a PAT goes in Basic as the password.
$headers = if ($AccessToken -match '^eyJ') {
    @{ Authorization = "Bearer $AccessToken" }
} else {
    @{ Authorization = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AccessToken")))" }
}

function Invoke-Ado {
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [string] $Method = 'Get',
        $Body
    )
    $splat = @{ Uri = $Uri; Method = $Method; Headers = $headers; ContentType = 'application/json' }
    if ($null -ne $Body) { $splat.Body = ($Body | ConvertTo-Json -Depth 100 -Compress) }
    try { Invoke-RestMethod @splat }
    catch {
        # A wrong org/project or an un-authorised token gets an HTML sign-in page, not JSON;
        # surface the status and body rather than a bare "Invalid JSON primitive".
        $resp = $_.Exception.Response
        $code = if ($resp) { [int]$resp.StatusCode } else { '?' }
        $detail = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        throw "$Method $Uri failed (HTTP $code): $detail"
    }
}

# --- Work out the value -----------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'FromArtefacts') {
    if (-not (Test-Path $ArtefactsPath)) { throw "Artefacts path not found: $ArtefactsPath" }

    # Only plans that were actually built have a folder, so the artefacts ARE the SKU list.
    $found = @()
    foreach ($dir in Get-ChildItem -Path $ArtefactsPath -Directory) {
        $file = Join-Path $dir.FullName "$($dir.Name).txt"
        if (-not (Test-Path $file)) { Write-Host "skip $($dir.Name) (no $($dir.Name).txt)" -ForegroundColor DarkGray; continue }

        $url = (Get-Content -Raw $file).Trim()
        if ($url -notmatch '/images/([^/]+)/versions/([^/?\s]+)') {
            throw "$file is not a gallery image-version resource id (.../images/<def>/versions/<x.y.z>): $url"
        }
        $imageVersion = $Matches[2]
        $parts = $imageVersion -split '\.'
        if ($parts.Count -lt 3) { throw "$file : image version '$imageVersion' has no third part to use as VersionText." }

        $found += [pscustomobject]@{ Plan = $dir.Name; ImageVersion = $imageVersion; VersionText = $parts[2] }
    }
    if (-not $found) { throw "No plan artefacts found under $ArtefactsPath - nothing to derive the value from." }

    $found | Sort-Object Plan | ForEach-Object {
        Write-Host ("  {0,-12} {1,-10} -> {2}" -f $_.Plan, $_.ImageVersion, $_.VersionText) -ForegroundColor DarkGray
    }

    # One build = one VersionText. Disagreement means mixed artefacts; refuse to guess.
    $distinct = @($found.VersionText | Sort-Object -Unique)
    if ($distinct.Count -gt 1) {
        throw ("Artefacts disagree on VersionText ({0}). The artefacts are from more than one build - resolve before updating $VariableName." -f ($distinct -join ', '))
    }

    $Value = $distinct[0]
    Write-Host ("Derived {0} = {1} from {2} tested plan artefact(s)." -f $VariableName, $Value, $found.Count) -ForegroundColor Cyan
}

# --- Resolve the group ------------------------------------------------------
$projectEnc = [uri]::EscapeDataString($Project)
$list = Invoke-Ado "$Organization/$projectEnc/_apis/distributedtask/variablegroups?groupName=$([uri]::EscapeDataString($VariableGroupName))&api-version=$ApiVersion"

$groups = @($list.value)
if ($groups.Count -eq 0) { throw "Variable group '$VariableGroupName' not found in $Organization/$Project." }
if ($groups.Count -gt 1) { throw "Variable group name '$VariableGroupName' is ambiguous ($($groups.Count) matches)." }
$group = $groups[0]

if ($group.type -ne 'Vsts') {
    throw "Variable group '$VariableGroupName' is of type '$($group.type)' (Key Vault-backed). Change the value in Key Vault, not here."
}

$vars = $group.variables
$existing = $vars.PSObject.Properties | Where-Object { $_.Name -eq $VariableName }
if (-not $existing) {
    throw "Variable '$VariableName' does not exist in group '$VariableGroupName'. This script updates; it does not create."
}
function Test-IsSecret($v) { ($v.PSObject.Properties.Name -contains 'isSecret') -and $v.isSecret }
if (Test-IsSecret $existing.Value) {
    throw "Variable '$VariableName' is a secret. Update it in the Library UI - this script only handles plaintext variables."
}
$current = if ($existing.Value.PSObject.Properties.Name -contains 'value') { $existing.Value.value } else { $null }

Write-Host ""
Write-Host "Group    : $VariableGroupName (id $($group.id))" -ForegroundColor Cyan
Write-Host "Variable : $VariableName"
Write-Host "Current  : $current"
Write-Host "New      : $Value"

if ($current -eq $Value) {
    Write-Host "Already set to '$Value' - nothing to do." -ForegroundColor Green
    return
}

# The GET does not return secret values, so PUTting the group back cannot preserve them
# reliably. Make that a hard stop rather than a silent risk to the rest of the group.
$secretNames = @($vars.PSObject.Properties | Where-Object { Test-IsSecret $_.Value } | Select-Object -ExpandProperty Name)
if ($secretNames) {
    $msg = "Group '$VariableGroupName' contains secret variable(s): $($secretNames -join ', '). The API replaces the whole group and the GET does not return secret values, so this PUT may clear them."
    if (-not $AllowSecrets) { throw "$msg Re-run with -AllowSecrets if you have verified this is safe, or change the variable in the Library UI." }
    Write-Host "WARNING: $msg Proceeding because -AllowSecrets was given." -ForegroundColor Yellow
}

# --- Write ------------------------------------------------------------------
if (-not $Submit) {
    Write-Host "`nDRY RUN - re-run with -Submit to apply." -ForegroundColor Yellow
    return
}

if (-not $ProjectId) {
    $ProjectId = (Invoke-Ado "$Organization/_apis/projects/$projectEnc`?api-version=$ApiVersion").id
}

# Change the one variable in place so every other property of the group round-trips verbatim.
$vars.$VariableName.value = $Value

# The 7.1 update is org-scoped and requires the project references to be restated.
$body = @{
    name        = $group.name
    description = $group.description
    type        = $group.type
    variables   = $vars
    variableGroupProjectReferences = @(
        @{ name = $group.name; description = $group.description; projectReference = @{ id = $ProjectId } }
    )
}

Invoke-Ado "$Organization/_apis/distributedtask/variablegroups/$($group.id)?api-version=$ApiVersion" -Method Put -Body $body | Out-Null

# Read back rather than trusting the response echo.
$after = (Invoke-Ado "$Organization/$projectEnc/_apis/distributedtask/variablegroups/$($group.id)?api-version=$ApiVersion").variables.$VariableName.value
if ($after -ne $Value) { throw "$VariableName reads back as '$after' after the update, expected '$Value'." }

Write-Host "`n$VariableName updated: $current -> $Value" -ForegroundColor Green
