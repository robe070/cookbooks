<#
.SYNOPSIS

Test java SDK is installed and working

.EXAMPLE

#>

if ( -not $script:IncludeDir)
{
    $script:IncludeDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\scripts'

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

try {
    cd "$Script:IncludeDir\..\tests"
    javac HelloWorld.java
    java HelloWorld
} catch {
    Write-Error $(Log-Date) ($_ | format-list | out-string)
    throw
}
Write-Output "Java SDK installed successfully"