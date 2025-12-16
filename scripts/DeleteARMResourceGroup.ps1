param (
    [Parameter(Mandatory=$true)]
    [string]
    $RGName
)
Write-Host "Deleting Resource Group $RGName frrom Azure"
Remove-AzResourceGroup -Name $RGName -Force -ErrorAction SilentlyContinue
while (Get-AzResourceGroup -Name $RGName -ErrorAction SilentlyContinue) {
   Write-Host ("Waiting 30 seconds for $RGName to be deleted...")
   Start-Sleep -Seconds 30
}