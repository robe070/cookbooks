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
      [Amazon.CloudFormation.Model.StackSummary[]]$stacks = Get-CFNStackSummary -Region $region -StackStatusFilter @("CREATE_FAILED", "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "CREATE_COMPLETE"  ) -NextToken $nextToken
      foreach ( $stack in $stacks )
      {
        Write-Output "$($stack.stackName) - $($stack.StackStatus)"
      }

      $nextToken = $AWSHistory.LastServiceResponse.NextToken
    } while ($nextToken -ne $null)
}
