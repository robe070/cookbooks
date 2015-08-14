<#
.SYNOPSIS

Initialise the baking environment include files

.DESCRIPTION



.EXAMPLE


#>

. "$Script:IncludeDir\dot-createlicense.ps1"
. "$Script:IncludeDir\dot-Create-EC2Instance.ps1"
. "$Script:IncludeDir\dot-Wait-EC2State.ps1"
. "$Script:IncludeDir\dot-Add-DirectoryToEnvPathOnce.ps1"
. "$Script:IncludeDir\dot-New-ErrorRecord.ps1"
. "$Script:IncludeDir\dot-Send-RemotingFile.ps1"
. "$script:IncludeDir\dot-CommonTools.ps1"
. "$script:IncludeDir\dot-AWSTools.ps1"
. "$script:IncludeDir\dot-DBTools.ps1"
. "$script:IncludeDir\dot-map-licensetouser.ps1"
. "$script:IncludeDir\dot-set-accesscontrol.ps1"
. "$script:IncludeDir\dot-Add-DirectoryToEnvPathOnce.ps1"    
Write-Debug "Include files loaded"

