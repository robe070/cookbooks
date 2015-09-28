<#
.SYNOPSIS

List all Ec2 running instances in all regions

.EXAMPLE


#>
$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "Region $region"
    Set-DefaultAWSRegion -Region $region

    $instances  = (get-ec2instance).instances | where {$_.state.name -eq "running"}
    $instances | fl InstanceId
}
