# Specify empty Database Password to use Windows Authentication to connect to the database
param(
    [Parameter(Mandatory=$false)]
    [String] $DatabaseServer=$($ENV:COMPUTERNAME),

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
    [String] $SystemBranch='patch/paas',     # The branch to use for the LANSA system git repositories

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $BaseMSIuri='https://s3.amazonaws.com/lansa-us-east-1/app/paas-test',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $app1RepoUrl='git@github.com:lansa/lansaeval10.git', # The application's git repository

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $app1Branch='master',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $Cloud='on-premise',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $MaxConnections=10,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [boolean] $f32bit=1
)

# This script was used with Windows Authentication and it all worked up to the point of the GitDeployHub deploying an application
# because the GitDepoyHub process runs under a system account which does not have access to the database. That may be re-configured,
# but for the purpose of this initial trial, it does not seem to be a big restriction to require a SQL Server login to access the database.

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

Write-Host( "Parameter values...")

Write-Host( "DatabaseServer = $DatabaseServer")
Write-Host( "DatabaseUser = $DatabaseUser")
Write-Host( "WebUser = $WebUser")
Write-Host( "SystemBranch = $SystemBranch")
Write-Host( "app1RepoUrl = $app1RepoUrl")
Write-Host( "app1Branch = $app1Branch")
Write-Host( "Cloud = $Cloud")
Write-Host( "BaseMSIuri = $BaseMSIuri")
Write-Host( "MaxConnections = $MaxConnections")

$MSIAppName = 'WEBSERVR'      # The application name specified in the Deployment Tool when creating the WebServer Package.

if ( $UPGD -eq 'true' -or $UPGD -eq '1')
{
    $UPGD_bool = $true
}
else
{
    $UPGD_bool = $false
}

$ApplName = "WebServer"
if ($f32bit) {
    $APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
} else {
    $APPA = "${ENV:ProgramFiles}\$($ApplName)"
}
Write-Output( "$(Log-Date) Companion Install Path $APPA" )

try {
    Write-Host( "$(Log-Date) Link the 32-bit and 64-bit registry hives." )

    &"$script:IncludeDir\lansa64reginit.exe"

     if ( 1 ){
        Write-Host( "$(Log-Date) Configure IIS...")

        # Windows 10 IIS Features
        $required_IIS_features = @(
            "IIS-WebServerRole",
            "IIS-WebServer",
            "IIS-WebServerManagementTools",
            "IIS-ManagementConsole",
            "IIS-CommonHttpFeatures",
            "IIS-HttpErrors",

            "IIS-ApplicationDevelopment",
            "IIS-ASPNET",
            "IIS-NetFxExtensibility",
            "IIS-ASPNET45",
            "IIS-NetFxExtensibility45",
            "NetFx4Extended-ASPNET45",

            "IIS-HealthAndDiagnostics",
            "IIS-LoggingLibraries",
            "IIS-RequestMonitor",
            "IIS-HttpTracing",
            "IIS-Security",
            "IIS-RequestFiltering",
            "IIS-Performance",
            "IIS-WebServerManagementTools",
            "IIS-ManagementConsole",
            "IIS-StaticContent",
            "IIS-DefaultDocument",
            "IIS-DirectoryBrowsing",
            "IIS-ISAPIExtensions",
            "IIS-ISAPIFilter",
            "IIS-HttpCompressionStatic",
            "IIS-CGI"
        )
        foreach ($feature in $required_IIS_features) {
            $FeatureState = Get-WindowsOptionalFeature -FeatureName $feature -Online
            if ( $FeatureState -and ($FeatureState.state -eq "Disabled") ) {
                Write-Host( "$(Log-Date) Enabling $Feature" )
                Write-Host( Enable-WindowsOptionalFeature -All -Online -FeatureName $feature | format-list | Out-String )
            } else {
                Write-Host( "$(Log-Date) $Feature is already configured" )
            }
        }

        Write-Host( "$(Log-Date) IIS Configuration complete")
     }

    $DBCredentials = New-Object System.Management.Automation.PSCredential `
        -ArgumentList $DatabaseUser, $DatabasePassword
    $WebCredentials = New-Object System.Management.Automation.PSCredential `
        -ArgumentList $WebUser, $WebPassword

    Write-Host( "$(Log-Date) Set up Registry..." )
    $LANSAKey = 'HKLM:\Software\LANSA'

    if ( -not (Test-Path -Path $LANSAKey) ) {
        New-Item -Path $LANSAKey | Out-Null
    }
    $GitBranchWebServer = New-ItemProperty -Path $LANSAKey -Name "GitBranch$MSIAppName" -Value $SystemBranch -PropertyType String -Force
    Write-Host( "GitBranchWebServer = $GitBranchWebServer" )

    $GitBranch = New-ItemProperty -Path $LANSAKey -Name 'GitBranch' -Value $SystemBranch -PropertyType String -Force
    Write-Host( "GitBranch = $GitBranch" )

    $Cloud = New-ItemProperty -Path $LANSAKey -Name 'Cloud' -Value $Cloud -PropertyType String -Force
    Write-Host( "Cloud = $Cloud")

    Write-Host( "$(Log-Date) Registry done" )

    Write-Host( "$(Log-Date) Install Webserver..." )

    cmd /c exit 0

    $CommonParams = @("-server_name $DatabaseServer", "-dbut MSSQLS", "-dbuser $DatabaseUser", "-dbpassword `"$($DBCredentials.GetNetworkCredential().Password)`"", "-webuser $WebUser", "-webpassword $($WebCredentials.GetNetworkCredential().Password)", "-f32bit $f32bit", "-HTTPPortNumber 80", "-HTTPPortNumberHub 8101", "-HostRoutePortNumber 4540", "-JSMPortNumber 4561", "-JSMAdminPortNumber 4581", "-SUDB 1", "-UPGD false")
    $Arguments = $CommonParams + @("-MSIUri $BaseMSIuri/WEBSERVR_v1.0.0_en-us.msi", "-ApplName $ApplName", "-dbname webserverauto", "-gitrepourl https://github.com/lansa/webserver.git", "-DisableSQLServer 0")
    $Arguments
    Invoke-Expression "& $script:IncludeDir\install-lansa-msi.ps1 $Arguments"

    if ( $LASTEXITCODE -ne 0) {
        throw "Error installing webserver"
    }

    Write-Host( "$(Log-Date) Webserver installed" )

    Write-Host( "$(Log-Date) Install Application..." )
    $ApplName = 'APP1'  # Note that LANSA MSI files use upper case characters. The rest are case insensitive.

    $Arguments = $CommonParams + @("-CompanionInstallPath `"$APPA`"", "-MSIUri $BaseMSIuri/$($ApplName)_v1.0.0_en-us.msi", "-ApplName $ApplName", "-dbname $ApplName", "-gitrepourl $app1RepoUrl", "-DisableSQLServer 0")
    $Arguments
    Invoke-Expression "& $script:IncludeDir\install-lansa-msi.ps1 $Arguments"
    if ( $LASTEXITCODE -ne 0) {
        throw "Error installing application"
    }
    Write-Host( "$(Log-Date) $ApplName installed" )


    # Do the Shared Licensing registry entry afdter teh MSI installs which delete the registry entry.

    Write-Host("$(Log-Date) Setting up shared licensing")
    # HKEY_LOCAL_MACHINE\SOFTWARE\LANSA\COMMON
    $KeyPath = "$LANSAKey\COMMON"
    if ( -not (Test-Path -Path $KeyPath) ) {
        New-Item -Path $KeyPath | Out-Null
    }
    $LicenseDir = New-ItemProperty -Path "$KeyPath" -Name "LicenseDir" -Value "${ENV:ProgramFiles(x86)}\Common Files\LANSA" -PropertyType String -Force
    Write-Host( "LicenseDir = $LicenseDir" )

    $ApplName = 'WebServer'
    Write-Host( "$(Log-Date) Configuring web plugin options for WebServer - all lansa applications")
    & "$script:IncludeDir\webconfig.ps1" -MaxConnections $MaxConnections -ApplName $ApplName -DBName $ApplName -Reset $true $CommonParams

} catch {
     $_

     Write-Host( "$(Log-Date) Target Deployment Automation failed" )

     return # presume LASTEXITCODE has already been set - e.g. by install-lansa.msi.ps1
}

Write-Host( "$(Log-Date) Target Deployment Automation successful" )

cmd /c exit 0
