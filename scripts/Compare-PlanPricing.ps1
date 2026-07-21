<#
.SYNOPSIS
    Groups an offer's plans by identical pricing, reading the price-and-availability-plan
    resources from an exported resource-tree JSON. Order-independent (markets/price lists
    are canonicalised) so cosmetic ordering differences don't count as mismatches.

.EXAMPLE
    .\Compare-PlanPricing.ps1 -TemplateFile .\9c420de5-...-draft.json
    .\Compare-PlanPricing.ps1 -TemplateFile .\9c420de5-...-draft.json -PlanExternalId w19d-15-0,w22d-15-0,...
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $TemplateFile,
    [string[]] $PlanExternalId,          # optional filter; default = all plans with pricing
    [switch] $IncludeMarkets,            # also factor markets + visibility into the grouping
    [string] $ExtractDir                 # if set, write one normalised {visibility,markets,pricing}
                                         # file per distinct signature, named by the first plan using it
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Allow a comma-separated string (e.g. via `pwsh -File`) as well as a real array
if ($PlanExternalId) { $PlanExternalId = $PlanExternalId -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

$tree = Get-Content -Raw $TemplateFile | ConvertFrom-Json
function Get-ResType($r) { ($r.'$schema' -split '/schema/')[-1] -replace '/.*$', '' }

# plan durable id -> externalId
$extById = @{}
foreach ($r in $tree.resources) { if ((Get-ResType $r) -eq 'plan') { $extById[$r.id] = $r.identity.externalId } }

# Canonical, order-independent serialisation
function Canon($o) {
    if ($null -eq $o) { return 'null' }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $parts = foreach ($p in ($o.PSObject.Properties | Sort-Object Name)) { '"' + $p.Name + '":' + (Canon $p.Value) }
        return '{' + ($parts -join ',') + '}'
    }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) {
        $items = @(foreach ($i in $o) { Canon $i }) | Sort-Object
        return '[' + ($items -join ',') + ']'
    }
    return ($o | ConvertTo-Json -Compress -Depth 2)
}
function Get-Hash($s) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s))) -replace '-', '').Substring(0, 12)
}
# Order-stable copy for readable diffs: keys sorted, scalar/market arrays sorted.
function Normalize($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in ($o.PSObject.Properties | Sort-Object Name)) { $h[$p.Name] = Normalize $p.Value }
        return [pscustomobject]$h
    }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) {
        $norm = @(foreach ($i in $o) { Normalize $i })
        return @($norm | Sort-Object { $_ | ConvertTo-Json -Compress -Depth 100 })
    }
    return $o
}

# Collect pricing per plan
$rows = @()
foreach ($r in $tree.resources) {
    if ((Get-ResType $r) -ne 'price-and-availability-plan') { continue }
    $ext = if ($extById.ContainsKey($r.plan)) { $extById[$r.plan] } else { "($($r.plan))" }
    if ($PlanExternalId -and $ext -notin $PlanExternalId) { continue }

    $sig = Canon $r.pricing
    if ($IncludeMarkets) {
        $vis = if ($r.PSObject.Properties.Name -contains 'visibility') { $r.visibility } else { '' }
        $mkts = if ($r.PSObject.Properties.Name -contains 'markets') { (Canon $r.markets) } else { '[]' }
        $sig = "$sig|vis=$vis|markets=$mkts"
    }
    $rows += [pscustomobject]@{
        Plan       = $ext
        PriceHash  = Get-Hash (Canon $r.pricing)
        Model      = $r.pricing.licenseModel
        Markets    = if ($r.PSObject.Properties.Name -contains 'markets') { $r.markets.Count } else { 0 }
        Visibility = if ($r.PSObject.Properties.Name -contains 'visibility') { $r.visibility } else { '' }
        GroupSig   = Get-Hash $sig
        Res        = $r
    }
}

if (-not $rows) { throw "No matching price-and-availability-plan resources found." }

Write-Host "Per-plan pricing:" -ForegroundColor Cyan
$rows | Sort-Object Plan | Format-Table Plan, PriceHash, Model, Markets, Visibility -AutoSize | Out-String | Write-Host

$groups = $rows | Group-Object GroupSig
Write-Host ("Distinct pricing group(s): {0}" -f $groups.Count) -ForegroundColor $(if ($groups.Count -eq 1) { 'Green' } else { 'Yellow' })
$i = 0
foreach ($g in ($groups | Sort-Object Count -Descending)) {
    $i++
    Write-Host ("  Group {0} ({1} plans): {2}" -f $i, $g.Count, (($g.Group.Plan | Sort-Object) -join ', '))
}
if ($groups.Count -eq 1) {
    Write-Host "`nAll compared plans share identical pricing." -ForegroundColor Green
} else {
    Write-Host "`nPricing differs across groups above - inspect the plans in the smaller group(s)." -ForegroundColor Yellow
    Write-Host "Add -IncludeMarkets to also compare markets/visibility." -ForegroundColor DarkGray
}

# --- Extract one normalised file per distinct signature --------------------
if ($ExtractDir) {
    if (-not (Test-Path $ExtractDir)) { New-Item -ItemType Directory -Path $ExtractDir | Out-Null }
    Write-Host "`nExtracting signature files to $ExtractDir :" -ForegroundColor Cyan
    foreach ($g in ($groups | Sort-Object Count -Descending)) {
        $first = $g.Group[0]                       # first plan (document order) using this signature
        $r     = $first.Res
        $content = [pscustomobject]@{
            visibility = if ($r.PSObject.Properties.Name -contains 'visibility') { $r.visibility } else { $null }
            markets    = if ($r.PSObject.Properties.Name -contains 'markets') { $r.markets } else { @() }
            pricing    = $r.pricing
        }
        $safe = ($first.Plan -replace '[^A-Za-z0-9._-]', '_')
        $file = Join-Path $ExtractDir "$safe-pricing.json"
        (Normalize $content) | ConvertTo-Json -Depth 100 | Set-Content -Path $file -Encoding UTF8
        Write-Host ("  {0,-26} <- {1}" -f (Split-Path $file -Leaf), (($g.Group.Plan | Sort-Object) -join ', '))
    }
}
