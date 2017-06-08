<#
.SYNOPSIS

List all stacks in all regions and if the stack creation is completed, the url of the LANSA website is tested.

It presumes all completed stacks are LANSA stacks with the standard WAM test installed.

It could be further modified to only run the test on stacks that are tagged as LANSA Stacks.

.EXAMPLE


#>
$Success = 0
$Fail = 0
$InProgress = 0
$OtherStates = 0
$TotalStacks = 0

$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "$region"

    $nextToken = $null
    do {
        # List ALL stack status EXCEPT for DELETE_COMPLETE which is the state that all deleted stacks are left in and the data is kept for many years!
      [Amazon.CloudFormation.Model.StackSummary[]]$stacks = Get-CFNStackSummary -Region $region -StackStatusFilter @("CREATE_FAILED", "DELETE_FAILED", "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "DELETE_IN_PROGRESS", "CREATE_COMPLETE", "ROLLBACK_IN_PROGRESS", "ROLLBACK_FAILED", "ROLLBACK_COMPLETE", "UPDATE_COMPLETE", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE", "UPDATE_ROLLBACK_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_ROLLBACK_FAILED", "UPDATE_ROLLBACK_IN_PROGRESS", "REVIEW_IN_PROGRESS"   ) -NextToken $nextToken
      foreach ( $stack in $stacks ) {
          $TotalStacks = += 1
        
         Write-Output "$($stack.stackName) - $($stack.StackStatus)"
         if ( $stack.StackStatus -eq 'CREATE_COMPLETE') {
            $StackDetails = Get-CFNStack -StackName $($stack.stackName) -Region $region
            $StackDetails.Outputs.OutputValue

            # First we create the request.
            $HTTP_Request = [System.Net.WebRequest]::Create("$($StackDetails.Outputs.OutputValue)/cgi-bin/lansaweb?wam=DEPTABWA&webrtn=BuildFirst&ml=LANSA:XHTML&part=DEX&lang=ENG" )

            # We then get a response from the site.
            $HTTP_Response = $HTTP_Request.GetResponse()

            # We then get the HTTP code as an integer.
            $HTTP_Status = [int]$HTTP_Response.StatusCode

            If ($HTTP_Status -eq 200) { 
               Write-Host "Site is OK!" 
               $Success += 1
            }
            Else {
               Write-Host "Site not available - Status = $HTTP_Status"
               $Fail += 1
            }

            # Finally, we clean up the http request by closing it.
            $HTTP_Response.Close()
         }
         elseif ( $stack.StackStatus -eq 'CREATE_IN_PROGRESS') {
            $InProgress += 1
         }
         else {
           $OtherStates += 1
         }
      }

      $nextToken = $AWSHistory.LastServiceResponse.NextToken
    } while ($nextToken -ne $null)
    Write-Output ("`r")
}

Write-Output( "Success    = $Success")
Write-Output( "Fail       = $Fail")
Write-Output( "InProgress = $InProgress")
Write-Output( "OtherStates = $OtherStates")
Write-Output( "TotalStacks = $TotalStacks")
