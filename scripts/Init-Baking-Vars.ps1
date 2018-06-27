<#
.SYNOPSIS

Initialise the baking environment

.DESCRIPTION



.EXAMPLE


#>


$script:SG = "bake-ami"
$script:externalip = $null
$script:keypair = "RobG_id_rsa"
$script:keypairfile = "$ENV:USERPROFILE\\.ssh\\id_rsa"
$script:licensekeypassword = $ENV:cloud_license_key
$script:ChefRecipeLocation = "$script:IncludeDir\..\ChefCookbooks"
$Script:GitRepo = 'lansa'
$Script:GitRepoPath = "c:\$Script:GitRepo"
$Script:ScriptTempPath = "c:\temp"
$Script:LicenseKeyPath = $Script:ScriptTempPath
$Script:InstanceProfileArn = "arn:aws:iam::775488040364:instance-profile/LansaInstalls_ec2"
$Script:DVDDir = 'c:\LanDvdCut'

# Make non-terminating errors into terminating errors. That is, the script will throw an exception so we know its gone wrong
$ErrorActionPreference = 'Stop'

cmd /c exit 0       # Set $LASTEXITCODE so it always exists. Saves testing it everywhere

Write-Debug "Variables loaded"
