<#
.SYNOPSIS

Test licenses are installed and working.

IMPORTANT:" To be run in a new instance created from the baked image, NOT while creating the image itself.

.EXAMPLE

#>
Param(
    [Parameter(Mandatory=$true)] [String] $ImgName,
    [Parameter(Mandatory=$true)] [String] $cloud
)
. "c:\lansa\scripts\dot-CommonTools.ps1"

if ( -not $script:IncludeDir)
{
	$script:IncludeDir = 'c:\lansa\scripts'
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS" | Out-Default | Write-Host
}

try {
    cd "$Script:IncludeDir\..\tests"

    if($cloud -eq 'Azure') {
        $WebUser = 'PCXUSER2'
    }
    elseif ($cloud -eq "AWS") {
        $WebUser = 'Administrator'
    }
   
    Write-Host "Webuser is $WebUser"
    Write-GreenOutput "Note: MUST create the user $WebUser manually before running this script AND add to local Administrators group" | Write-Host

    &"$Script:IncludeDir\activate-all-licenses.ps1"  $WebUser

} catch {
    Write-RedOutput $_ | Out-Default | Write-Host
    throw "$(Log-Date) License installation error"
}
Write-GreenOutput "All licenses tested successfully" | Out-Default | Write-Host