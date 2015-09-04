<#
.SYNOPSIS

Initialise the baking environment

.DESCRIPTION



.EXAMPLE


#>


$Script:DialogTitle = "LANSA IDE "
$script:SG = "bake-ami"
$script:externalip = $null
$script:keypair = "RobG_id_rsa"
$script:keypairfile = "$ENV:USERPROFILE\\.ssh\\id_rsa"
$script:licensekeypassword = $ENV:cloud_license_key
$script:gitbranch = 'marketplace-and-stt'
$script:ChefRecipeLocation = "$script:IncludeDir\..\ChefCookbooks"
$Script:GitRepo = 'lansa'
$Script:GitRepoPath = "c:\$Script:GitRepo"
$Script:ScriptTempPath = "c:\temp"
$Script:LicenseKeyPath = $Script:ScriptTempPath
$Script:InstanceProfileArn = "arn:aws:iam::775488040364:instance-profile/LansaInstalls_ec2"
$Script:DVDDir = 'c:\LanDvdCut'

Write-Debug "Variables loaded"
