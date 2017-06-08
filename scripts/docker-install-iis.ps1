# presumes that these directories exist:
# c:\temp mapped to host temporary directory
# c:\scripts to host  Cookbooks\scripts
# c:\lansa container directory for the msi location

Write-Output "Installing IIS"
import-module servermanager
install-windowsfeature web-server

Write-Output "Enabling Remote IIS Management"
install-windowsfeature web-mgmt-service
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
Set-Service -name WMSVC -StartupType Automatic
Start-service WMSVC


Write-Output "Turning off complex password requirements"
secedit /export /cfg c:\secpol.cfg
(Get-Content C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
Remove-Item -force c:\secpol.cfg -confirm:$false

Write-Output "Create local user test (pwd=test)"
NET USER test "test" /ADD
NET LOCALGROUP "Administrators" "test" /ADD

Write-Output "Set LANSA Cloud registry entries"
$lansaKey = 'HKLM:\Software\LANSA\'
if (!(Test-Path -Path $lansaKey)) {
   New-Item -Path $lansaKey
}
New-ItemProperty -Path $lansaKey  -Name 'Cloud' -PropertyType String -Value 'Docker' -Force

New-Item -ItemType directory -Path C:\lansa -Force

# Temporarily copy in Windows System DLLs
# Copy current versions rather than the contents of a temporary directory which will become out of date
Set-Location c:\HostSystem

Copy-Item oledlg.dll c:\windows\syswow64

# The following DLLs are thought to not be required.

if ( $false -eq $true) {
   Copy-Item aepic.dll c:\windows\syswow64
   Copy-Item avifil32.dll c:\windows\syswow64
   Copy-Item en-US\avifil32.dll.mui c:\windows\syswow64
   Copy-Item avrt.dll c:\windows\syswow64
   Copy-Item chakra.dll c:\windows\syswow64
   Copy-Item comppkgsup.dll c:\windows\syswow64
   Copy-Item coreuicomponents.dll c:\windows\syswow64
   Copy-Item cryptngc.dll c:\windows\syswow64
   Copy-Item dcomp.dll c:\windows\syswow64
   Copy-Item devmgr.dll c:\windows\syswow64
   Copy-Item dmpushproxy.dll c:\windows\syswow64
   Copy-Item dsreg.dll c:\windows\syswow64
   Copy-Item edputil.dll c:\windows\syswow64
   Copy-Item efsadu.dll c:\windows\syswow64
   Copy-Item efswrt.dll c:\windows\syswow64
   Copy-Item elscore.dll c:\windows\syswow64
   Copy-Item ieadvpack.dll c:\windows\syswow64
   Copy-Item ieapfltr.dll c:\windows\syswow64
   Copy-Item ieframe.dll c:\windows\syswow64
   Copy-Item ieui.dll c:\windows\syswow64
   Copy-Item imgutil.dll c:\windows\syswow64
   Copy-Item inetcomm.dll c:\windows\syswow64
   Copy-Item iri.dll c:\windows\syswow64
   Copy-Item mfplat.dll c:\windows\syswow64
   Copy-Item msacm32.dll c:\windows\syswow64
   Copy-Item msfeeds.dll c:\windows\syswow64
   Copy-Item mshtml.dll c:\windows\syswow64
   Copy-Item msoert2.dll c:\windows\syswow64
   Copy-Item occache.dll c:\windows\syswow64
   Copy-Item omadmapi.dll c:\windows\syswow64
   Copy-Item onex.dll c:\windows\syswow64
   Copy-Item policymanager.dll c:\windows\syswow64
   Copy-Item rtworkq.dll c:\windows\syswow64
   Copy-Item shdocvw.dll c:\windows\syswow64
   Copy-Item tapi32.dll c:\windows\syswow64
   Copy-Item wlanapi.dll c:\windows\syswow64
   Copy-Item wpaxholder.dll c:\windows\syswow64
   Copy-Item wpcwebfilter.dll c:\windows\syswow64
}