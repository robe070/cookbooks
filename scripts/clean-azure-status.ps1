param(
[string]  $StatusFile='0.status')

$StatusDir = 'C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\status\'
$StatusPath = $StatusDir + $StatusFile
$StatusPathOut = $StatusDir + 'out.status'

if ( (Test-Path $StatusPath) ) {
    (Get-Content $StatusPath).replace('\\n', "`r`n") | Set-Content $StatusPathOut
} else {
    Write-Output "Error: $StatusPath does not exist"
}