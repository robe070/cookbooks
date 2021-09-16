
$Regions = Get-AWSRegion
foreach ($Region in $Regions) {
    Write-Host( $Region )
    if ( $Region -like 'us-iso*') {
        Write-Host( "Skipping $Region")
        Continue
    }
    Get-CFNStackSummary -Region $Region -StackStatusFilter @("CREATE_COMPLETE", "CREATE_FAILED", "DELETE_FAILED", "UPDATE_FAILED") | Where-Object {$_.ParentId -eq $null} | select-Object -Property StackName, StackStatus | Format-Table
}