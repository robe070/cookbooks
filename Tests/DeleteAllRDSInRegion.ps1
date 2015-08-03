<#
.SYNOPSIS

Delete all RDS in a region!

.EXAMPLE


#>
param(
[String]$region="ap-southeast-2"
)
$rdsList = Get-RDSDBInstance -Region $region
foreach ($rds in $rdslist)
{
    $rds.DBInstanceIdentifier
    Remove-RDSDBInstance  -region $region -DBInstanceIdentifier $rds.DBInstanceIdentifier -SkipFinalSnapshot $True -Force
}
