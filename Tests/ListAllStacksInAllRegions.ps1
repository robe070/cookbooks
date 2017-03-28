<#
.SYNOPSIS

List all stacks in all regions

.EXAMPLE


#>
$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "$region"

    $nextToken = $null
    do {
        # List ALL stack status EXCEPT for DELETE_COMPLETE which is the state that all deleted stacks are left in and the data is kept for many years!
      [Amazon.CloudFormation.Model.StackSummary[]]$stacks = Get-CFNStackSummary -Region $region -StackStatusFilter @("CREATE_FAILED", "DELETE_FAILED", "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "DELETE_IN_PROGRESS", "CREATE_COMPLETE", "ROLLBACK_IN_PROGRESS", "ROLLBACK_FAILED", "ROLLBACK_COMPLETE", "UPDATE_COMPLETE", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE", "UPDATE_ROLLBACK_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_ROLLBACK_FAILED", "UPDATE_ROLLBACK_IN_PROGRESS", "REVIEW_IN_PROGRESS"   ) -NextToken $nextToken
      foreach ( $stack in $stacks )
      {
        Write-Output "$($stack.stackName) - $($stack.StackStatus)"
      }

      $nextToken = $AWSHistory.LastServiceResponse.NextToken
    } while ($nextToken -ne $null)
    Write-Output ("`r")
}
