<#
.SYNOPSIS

Delete all stacks in all regions

.EXAMPLE


#>

Write-Host "This script is intended to be used to delete the scalable stacks that are used to test the scalable image works in all regions with the scalable template."
Write-Host "N.B. Its is imperative to list all stacks first using its companion ListAllStacksInAllRegions.ps1 and ensure that only the stacks you want to delete will be deleted."

$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "$region"

    $nextToken = $null
    do {
      [Amazon.CloudFormation.Model.StackSummary[]]$stacks = Get-CFNStackSummary -Region $region -StackStatusFilter @("CREATE_FAILED", "DELETE_FAILED", "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "DELETE_IN_PROGRESS", "CREATE_COMPLETE", "ROLLBACK_IN_PROGRESS", "ROLLBACK_FAILED", "ROLLBACK_COMPLETE", "UPDATE_COMPLETE", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE", "UPDATE_ROLLBACK_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_ROLLBACK_FAILED", "UPDATE_ROLLBACK_IN_PROGRESS", "REVIEW_IN_PROGRESS" ) -NextToken $nextToken
      foreach ( $stack in $stacks )
      {
        Write-Output "$($stack.stackName) - $($stack.StackStatus)"
        if ( $stack.stackName -eq 'Scalable' -and ($stack.StackStatus -eq 'CREATE_COMPLETE' -or $stack.StackStatus -eq 'UPDATE_COMPLETE')) {
            Write-Host "Deleting $($stack.stackName)..."
            Remove-CFNStack -Region $region -StackName $stack.StackName -Force
        } else {
            Write-Host "Skipping $($stack.stackName)"
        }
      }

      $nextToken = $AWSHistory.LastServiceResponse.NextToken
    } while ($null -ne $nextToken)
}
