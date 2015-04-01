Function Get-RegistryKeyPropertiesAndValues

{

  <#

   .Synopsis

    This function accepts a registry path and returns all reg key properties and values

   .Description

    This function returns registry key properies and values.

   .Example

    Get-RegistryKeyPropertiesAndValues -path 'HKCU:\Volatile Environment'

    Returns all of the registry property values under the \volatile environment key

   .Parameter path

    The path to the registry key

   .Notes

    NAME:  Get-RegistryKeyPropertiesAndValues

    AUTHOR: ed wilson, msft

    LASTEDIT: 05/09/2012 15:18:41

    KEYWORDS: Operating System, Registry, Scripting Techniques, Getting Started

    HSG: 5-11-12

   .Link

     Http://www.ScriptingGuys.com/blog

 #Requires -Version 2.0

 #>

 Param(

  [Parameter (Mandatory=$true )]

  [string ]$path)

 Push-Location

 Set-Location -Path $path

 Get-Item . |

 Select-Object -ExpandProperty property |

 ForEach-Object {

 New-Object psobject -Property @{"property"= $_;

    "Value" = (Get-ItemProperty -Path . -Name $_). $_}}

 Pop-Location

} #end function Get-RegistryKeyPropertiesAndValues

$Logfile = "C:\Windows\Temp\startup.log"

function LogWrite {
   Param ( [object] $logstring)
   $now = Get-Date -format u
   Add-Content $Logfile $now
   Add-Content $Logfile $LogString
   Write-Output $logstring
}

function Log-RegistryKeyPropertiesAndValues {
    Param (
        [Parameter(Mandatory =$true) ][string] $regkey)

    LogWrite ($regkey )

    $values = Get-RegistryKeyPropertiesAndValues $regkey -ErrorAction SilentlyContinue
    if ( $values )
    {
        LogWrite ($values ) | format-list
    }
    else
    {
        LogWrite ("No values" )
    }
}

LogWrite( "Entries are listed in the order they are executed" )
LogWrite( "All keys are executed asynchronously except for entries in the HKEY_LOCAL_MACHINE\...\RunOnce key" )
LogWrite( "Executed when booting..." )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServicesOnce" )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices" )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\RunServicesOnce" )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\RunServices" )
LogWrite( "Executed when somebody logs on..." )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce" )
Log-RegistryKeyPropertiesAndValues( "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run" )
LogWrite( "Executed when the current user logs on..." )
Log-RegistryKeyPropertiesAndValues( "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" )
Log-RegistryKeyPropertiesAndValues( "HKCU:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run" )
# Log StartUpFolder here
Log-RegistryKeyPropertiesAndValues( "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" )
Log-RegistryKeyPropertiesAndValues( "HKCU:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce" )
