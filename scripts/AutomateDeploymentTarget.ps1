# Specify empty Database Password to use Windows Authentication to connect to the database
param(
    [Parameter(Mandatory=$false)]
    [String] $DatabaseUser='lansa',

    [Parameter(Mandatory=$true)]
    [SecureString] $DatabasePassword,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $WebUser='pcxuser2',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [SecureString] $WebPassword,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $SystemBranch='debug/paas',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $app1RepoUrl='git@github.com:lansa/lansaeval10.git',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $app1Branch='master',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $Cloud='on-premise'
)

#Requires -RunAsAdministrator

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

try {
     $MSIAppName = 'WEBSERVR'      # The application name specified in the Deployment Tool when creating the Package.

     $DBCredentials = New-Object System.Management.Automation.PSCredential `
          -ArgumentList $DatabaseUser, $DatabasePassword
     $WebCredentials = New-Object System.Management.Automation.PSCredential `
          -ArgumentList $DatabaseUser, $DatabasePassword

     if ( 0 ){
          Write-Output( "$(Log-Date) Configure IIS...")
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors
          # Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment

          Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility
          Enable-WindowsOptionalFeature -online -FeatureName NetFx4Extended-ASPNET45
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45

          Enable-WindowsOptionalFeature -Online -FeatureName IIS-HealthAndDiagnostics
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-LoggingLibraries
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestMonitor
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpTracing
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-Security
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-Performance
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools
          #Enable-WindowsOptionalFeature -Online -FeatureName IIS-IIS6ManagementCompatibility
          #Enable-WindowsOptionalFeature -Online -FeatureName IIS-Metabase
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole
          #Enable-WindowsOptionalFeature -Online -FeatureName IIS-BasicAuthentication
          #Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-DirectoryBrowsing
          #Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets
          #Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationInit
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIExtensions
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIFilter
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpCompressionStatic
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-CGI

          Write-Output( "IIS Configuration complete")
     }

     Write-Output( "$(Log-Date) Set up Registry..." )
     $LANSAKey = 'HKLM:\Software\LANSA'

     New-Item -Path $LANSAKey -Force | Out-Null
     $GitBranchWebServer = New-ItemProperty -Path $LANSAKey -Name "GitBranch$MSIAppName" -Value $SystemBranch -PropertyType String -Force
     Write-Output( "GitBranchWebServer = $GitBranchWebServer" )

     $GitBranch = New-ItemProperty -Path $LANSAKey -Name 'GitBranch' -Value $SystemBranch -PropertyType String -Force
     Write-Output( "GitBranch = $GitBranch" )

     $Cloud = New-ItemProperty -Path $LANSAKey -Name 'Cloud' -Value $Cloud -PropertyType String -Force
     $Cloud

     Write-Output( "$(Log-Date) Registry done" )

     Write-Output( "$(Log-Date) Install Webserver" )

     cmd /c exit 0
     & {C:\LANSA\scripts\install-lansa-msi.ps1 -MSIUri https://s3.amazonaws.com/lansa-us-east-1/app/paas-test/WEBSERVR_v1.0.0_en-us.msi -ApplName WebServer `
     -server_name  $ENV:COMPUTERNAME -dbut MSSQLS -dbname webserver -dbuser $DatabaseUser -dbpassword $DBCredentials.GetNetworkCredential().Password `
     -gitrepourl git@github.com:lansa/webserver.git -f32bit 1 `
     -HTTPPortNumber 80 -HTTPPortNumberHub 8101 -HostRoutePortNumber 4540 -JSMPortNumber 4561 -JSMAdminPortNumber 4581 `
     -SUDB 1 -UPGD false}

     if ( $LASTEXITCODE -ne 0) {
          throw "Error installing webserver"
     }

     Write-Output( "$(Log-Date) Webserver installed" )

} catch {
     $_

     Write-Output( "$(Log-Date) Target Deployment Automation failed" )

     return # presume LASTEXITCODE has already been set - e.g. by install-lansa.msi.ps1
}

Write-Output( "$(Log-Date) Target Deployment Automation successful" )

cmd /c exit 0
