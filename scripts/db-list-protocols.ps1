# Load SMO Wmi.ManagedComputer assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | out-null

# Then, it's just a matter of connecting to the server (not the instance), and looking through the ManagedComputer object's ClientProtocols collection.

# Connect to the instance using SMO
$hostname = hostname
$m = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') "$hostname"

# Return the protocols and whether or not they're enabled.
$m.ClientProtocols | select DisplayName, IsEnabled
