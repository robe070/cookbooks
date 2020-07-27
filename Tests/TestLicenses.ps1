<#
.SYNOPSIS

Test licenses are installed and working.

IMPORTANT:" To be run in a new instance created from the baked image, NOT while creating the image itself.

.EXAMPLE

#>
. "c:\lansa\scripts\dot-CommonTools.ps1"

if ( -not $script:IncludeDir)
{
	$script:IncludeDir = 'c:\lansa\scripts'
}
else
{
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

try {
    cd "$Script:IncludeDir\..\tests"

    $WebUser = 'PCXUSER2'
    Write-GreenOutput "Note: MUST create the user $webuser manually before running this script AND add to local Administrators group"

    &"$Script:IncludeDir\activate-all-licenses.ps1"  $webuser

} catch {
    Write-RedOutput $_
    throw "$(Log-Date) License installation error"
}
Write-GreenOutput "All licenses tested successfully"