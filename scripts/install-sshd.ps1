<#
.SYNOPSIS

Install sshd in an AWS instance without requiring a password that may be used to break into server
Requires using LocalSystem as the sshd logged on user

Download & install cygwin including openssh.
Use cygwin script to configure ssd
Fix up install
    Change owner of config files back to Administrator
    Relax permissions on config files
    Get public key from metadata
    Change credentials of sshd service to LocalSystem
    Open port 22
    Delete temporary cyg_server user
    Enable LSA so that LocalSystem can start a process as another user.
    Reboot machine to finish LSA configuration

N.B. Must use LF for line endings, not CRLF
Reboot is definitely required

.EXAMPLE

Add contents of this file to the AWS UserData when launching an instance.
Or reference it as a file in UserData when launching an instance

#>

# This password is only used temporarily
$password = "lansa@122"
$logon_user = "LocalSystem"
$service_name = "sshd"

$cygwin = "cygwin64"
$cygwin_dir = ( Join-Path -Path "c:" -ChildPath $cygwin )
$cygwin_dir_nix =   "/cygdrive/c/" + $cygwin
$cygwin_out = ( Join-Path -Path $cygwin_dir -ChildPath cygwin_install.log )
$cygwin_err = ( Join-Path -Path $cygwin_dir -ChildPath cygwin_install_err.log )

# Download and install Cygwin SSH
$installer = "setup-x86_64.exe"
$installer_url = "https://cygwin.com/setup-x86_64.exe"
# 4/6/15: Found that the latest version of CYGWIN SSH was causing problems with the Packer script. 
# Powershell output wasn't being displayed and sysprep (through EC2Config) was hanging.
# $installer_file = ( Join-Path -Path $ENV:USERPROFILE -ChildPath $installer )
# ( New-Object Net.WebClient ). DownloadFile($installer_url, $installer_file)
# Start-Process -FilePath $installer_file -ArgumentList @( "--quiet-mode" , "-s http://mirrors.163.com/cygwin", "--packages cygrunsrv,libattr1,syslog-ng,openssh", "-D", "-L", "-R $cygwin_dir" , "-l $cygwin_dir" ) -Wait -RedirectStandardOutput $cygwin_out -RedirectStandardError $cygwin_err
# =========================================================================================
# MAKE SURE TO COPY setup-x86_64.exe TO c:\ AND THE INSTALL IMAGE TO C:\cygwinInstallImage
# =========================================================================================
$installer_file = ( Join-Path -Path "c:" -ChildPath $installer )
Start-Process -FilePath $installer_file -ArgumentList @( "--quiet-mode" , "--packages cygrunsrv,libattr1,syslog-ng,openssh", "-L", "-R $cygwin_dir" , "-l c:\cygwinInstallImage" ) -Wait
# Get-Content $cygwin_out
# Get-Content $cygwin_err

# Set path to cygwin utils
$env:Path = "$cygwin_dir\bin;" + $env:Path

# Config the service answering yes to everything and using default cyg_server user. If LocalSystem is used here, nobody will have access to any of the configuration files!
# Must ensure cygwin bash is run (Chef has one too) otherwise relative directories in cygwin are not found
net user cyg_server /delete
bash.exe -c "ssh-host-config -y -w $password "

# Now make it work the way we want
# Change owner of ssh files to Administrator, so we can modify them!
$etc_path = $cygwin_dir_nix + "/etc/ssh*"
bash.exe -c "/usr/bin/chown Administrator $etc_path"


# Change StrictModes yes to StrictModes no in sshd_config file
# Change UsePrivilegeSeparation yes to UsePrivilegeSeparation no

$settings = "etc\sshd_config"
$settings_file = ( Join-Path -Path $cygwin_dir -ChildPath $settings )

# Save default config file
copy-item -Path $settings_file -Destination ( $settings_file + "_factory_default" )

((Get-Content $settings_file) |
Foreach-Object {
    $line = $_
    if ($line.Contains("#StrictModes yes" ) -or $line.Contains( "StrictModes yes")){
        write-host 'Old Value:' $line
        $line = "StrictModes no"
        write-host "New value:" $line
    } else {
        if ($line.Contains("UsePrivilegeSeparation yes" )){
            write-host 'Old Value:' $line
            $line = "UsePrivilegeSeparation no"
            write-host "New value:" $line
        }
    }
    #output line (to file)
    $line
}) | Set-Content ($settings_file )

# Import RSA public key from instance meta-data and output to authorized_keys file
$key_file = "authorized_keys"
$key_dir = $cygwin_dir + "\home\Administrator\.ssh"
$key_path = ( Join-Path -Path $key_dir -ChildPath $key_file )
$key_url = "http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key"
New-Item -ItemType Directory -Force -Path $key_dir
( New-Object Net.WebClient ). DownloadFile($key_url, $key_path)

# change credentials of ssh service to the requested user
$service = gwmi win32_service -computer $ENV:COMPUTERNAME -filter "name='$service_name'"
$service

$service_return = $service.change( $null,$null ,$null, $null,$null ,$null, $logon_user,$null )
if ( $service_return.ReturnValue -ne 0) {
    Write-Host "failed to change log on user for service $service_name to $logon_user"
} else {
    Write-Host "log on user for service $service_name changed to $logon_user "
}

# Open windows firewall port for ssh
netsh advfirewall firewall add rule name='ssh' dir=in protocol=tcp localport=22 action=allow profile=any

# Delete cyg_server as we are now using Local System
net user cyg_server /delete

# Enable LSA
bash.exe -c "auto_answer=yes;export auto_answer;cyglsa-config"

# reboot machine
# shutdown -r
