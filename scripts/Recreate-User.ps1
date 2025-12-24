# Stop the Listener service first (replace with exact LANSA Listener service name from services.msc)
#Stop-Service -Name "LANSA Listener" -Force  # Example name; confirm yours

# Delete any existing profile folder
Remove-Item -Path "C:\Users\PCXUSER2" -Recurse -Force -ErrorAction SilentlyContinue

# Delete the user account
net user PCXUSER2 /delete

# Recreate the local user (strong password; LANSA may override later)
$Password = ConvertTo-SecureString "Pcxuser122robg" -AsPlainText -Force
New-LocalUser -Name "PCXUSER2" -Password $Password -FullName "PCXUSER2" -Description "LANSA Runtime User" -PasswordNeverExpires

# Reapply logon rights
# Grant-UserRight -UserName "PCXUSER2" -Rights @("SeInteractiveLogonRight", "SeBatchLogonRight", "SeServiceLogonRight")