<#
.SYNOPSIS

Delete all stacks in all regions

.EXAMPLE


#>

Write-Host "This script is intended to be used to delete the scalable stacks that are used to test that the scalable image works in all regions with the scalable template."
Write-Host "N.B. It is imperative to list all stacks first using its companion ListAllStacksInAllRegions.ps1 and ensure that only the stacks you want to delete will be deleted."

$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Host "$region"

    Write-Host "Deleting Scalable..."
    Remove-CFNStack -Region $region -StackName 'Scalable' -Force
}
