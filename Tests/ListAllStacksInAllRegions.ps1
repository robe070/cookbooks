<#
.SYNOPSIS

List all stacks in all regions

.EXAMPLE


#>
$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "Region $region"

    $nextToken = $null
    do {
      [Amazon.CloudFormation.Model.StackSummary[]]$stack = Get-CFNStackSummary -Region $region -StackStatusFilter @("CREATE_FAILED", "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "CREATE_COMPLETE"  ) -NextToken $nextToken
      foreach ( $stackName in $stack.StackName )
      {
        Write-Output "Stack Name = $stackName"
      }

      $nextToken = $AWSHistory.LastServiceResponse.NextToken
    } while ($nextToken -ne $null)
}
