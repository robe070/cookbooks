# Stop the Listener service first (replace with exact LANSA Listener service name from services.msc)
#Stop-Service -Name "LANSA Listener" -Force  # Example name; confirm yours

$user = "<user>"
$PasswordText = "<password>"

# Delete any existing profile folder
Remove-Item -Path "C:\Users\$user" -Recurse -Force -ErrorAction SilentlyContinue

# Delete the user account
net user $user /delete

# Recreate the local user (strong password; LANSA may override later)
$Password = ConvertTo-SecureString $PasswordText -AsPlainText -Force
New-LocalUser -Name $user -Password $Password -FullName $user -Description "LANSA Runtime User" -PasswordNeverExpires