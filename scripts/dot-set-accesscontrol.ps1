<#
.SYNOPSIS

Sets the access control for an object

Refer To this link for parameter values: https://technet.microsoft.com/en-us/library/ff730951.aspx

.EXAMPLE
# Subfolders only
Set-Access-Control "PCXUSER2" "C:\Windows\Temp" "Modify" "ContainerInherit" "InheritOnly"

# This folder only
Set-Access-Control "PCXUSER2" "C:\Windows\Temp" "Modify"

# This folder, Sub folders and files
Set-Access-Control "PCXUSER2" "C:\Windows\Temp" "Modify" "ContainerInherit, ObjectInherit"

#>
function Set-Access-Control {
   Param (
	   [string]$webuser,
	   [string]$path,
	   [string]$rights,
	   [string]$inheritanceflag = "None",
	   [string]$propagationflag = "None",
	   [string]$type = "Allow"
   )

    $acl=(Get-Item $path).GetAccessControl('Access')
    $permission= $webuser, $rights, $inheritanceflag, $propagationflag, $type
    $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.AddAccessRule($accessRule)
    Set-Acl $path $acl
}
