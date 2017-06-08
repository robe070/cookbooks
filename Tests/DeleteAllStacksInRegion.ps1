<#
.SYNOPSIS

Delete all stacks in a region!

.EXAMPLE


#>
param(
[String]$region="ap-southeast-2"
)
$nextToken = $null
do {
  [Amazon.CloudFormation.Model.StackSummary[]]$stack = Get-CFNStackSummary -Region $region -StackStatusFilter @("CREATE_FAILED", "DELETE_FAILED", "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "DELETE_IN_PROGRESS", "CREATE_COMPLETE", "ROLLBACK_IN_PROGRESS", "ROLLBACK_FAILED", "ROLLBACK_COMPLETE", "UPDATE_COMPLETE", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE", "UPDATE_ROLLBACK_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_ROLLBACK_FAILED", "UPDATE_ROLLBACK_IN_PROGRESS", "REVIEW_IN_PROGRESS" ) -NextToken $nextToken
  foreach ( $stackName in $stack.StackName )
  {
    Write-Output "Stack Name = $stackName"
    Remove-CFNStack -Region $region -StackName $StackName -Force
  }
  

  $nextToken = $AWSHistory.LastServiceResponse.NextToken
} while ($nextToken -ne $null)
