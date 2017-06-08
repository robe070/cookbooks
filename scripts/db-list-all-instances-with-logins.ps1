# Enumerate all SQL Server instances
$hostname = hostname
$SqlServices = Get-Service -ComputerName $hostname -DisplayName 'SQL Server (*'

# pull out the instance names from the service names using a calculated property with Select-Object.
$InstanceNames = $SqlServices | Select-Object @{ n = 'Instance'; e = { $_.DisplayName.Trim('SQL Server ').Trim(')').Trim('(') } } | Select-Object -ExpandProperty Instance

foreach ($Instance in $InstanceNames) {
    Write-Output ("$instance")
	if ($Instance -eq 'MSSQLSERVER') {
	    $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $hostname
	} else {
	    $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "$hostname`\$Instance"
	}
	$Server.Logins
}
