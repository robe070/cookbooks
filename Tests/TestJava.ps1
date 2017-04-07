<#
.SYNOPSIS

Test java SDK is installed and working

.EXAMPLE

#>
try {
    cd "$Script:IncludeDir\..\tests"
    javac HelloWorld.java
    java HelloWorld
} catch {
    Write-Error $(Log-Date) ($_ | format-list | out-string)
    throw
}
Write-Output "Java SDK installed successfully"