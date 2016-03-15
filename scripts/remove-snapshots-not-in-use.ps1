<#
.DESCRIPTION
    Finds snapshots for a given volume and criteria about the snapshot.
    Will not delete a snapshot if its in use by an AMI
    
.NOTES
    PREREQUISITES:
    1) AWS Tools for PowerShell from http://console.aws.amazon.com/powershell/
    2) Credentials and region stored in session using Initialize-AWSDefault.
    For more info, see http://docs.aws.amazon.com/powershell/latest/userguide//specifying-your-aws-credentials.html 
.EXAMPLE
    powershell.exe .\SG_FindSnapshots.ps1
#>

# Criteria to use to filter the results returned.
$snapshotID = "*"
$status = "*"

# Define filters.
$filter1 = New-Object Amazon.EC2.Model.Filter
$filter1.Name = "snapshot-id"
$filter1.Value.Add($snapshotID)

$filter2 = New-Object Amazon.EC2.Model.Filter
$filter2.Name = "status"
$filter2.Value.Add($status)

$mySnapshots = get-EC2Snapshot -OwnerId '775488040364' -Filter $filter1, $filter2
$count = 0
foreach ($s in $mySnapshots) { 
    
    # Meets criteria.
    $count +=1
    $sb = $s.snapshotID + ", " + $s.State + ", " + $s.Attachments.instanceId
    Write-Output($sb)

    Remove-EC2Snapshot -snapshotid $s.snapshotID -ErrorAction Ignore -Force:$true
}
Write-Output ("Found " + $count + " snapshots that matched the criteria.")