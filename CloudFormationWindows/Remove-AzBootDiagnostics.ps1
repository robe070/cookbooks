$saParams = @{
    'ResourceGroupName' = 'BakingDp'
    'Name' = 'stagingdpauseast'
}
$diagContainerName = 'bootdiagnostics-*'

$DiagContainers = @(Get-AzStorageAccount @saParams | Get-AzStorageContainer | where { $_.Name -like $diagContainerName })
$DiagContainers
$DiagContainers | Remove-AzStorageContainer -Force