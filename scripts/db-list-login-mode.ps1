# Connect to the instance using SMO
$Hostname = Hostname
$s = new-object ('Microsoft.SqlServer.Management.Smo.Server') "$Hostname"
[string]$nm = $s.Name
[string]$mode = $s.Settings.LoginMode

write-output "Instance Name: $nm"
write-output "Login Mode: $mode"