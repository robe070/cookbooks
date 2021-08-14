[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [Switch]
    $Lang=$false
)
Write-Host ("test1 Lang = $Lang" )
.\test2.ps1 -Lang:$Lang