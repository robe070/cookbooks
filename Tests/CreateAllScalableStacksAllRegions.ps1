<#
.SYNOPSIS

Create a single LANSA Stack in every region so it may be tested in browser.

N.B. The keyPair specified must be in EVERY region.

.EXAMPLE


#>

$ErrorCount = 0
$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Host "Region $region"

    try
    {
        Write-Host "$InstanceType"
        New-CFNStack -region $region `
        -StackName "Scalable" `
        -DisableRollback $True `
        -Capability CAPABILITY_IAM `
        -templateURL  	https://s3-ap-southeast-2.amazonaws.com/lansa/templates/support/L4W14200_scalable/lansa-win-custom.cfn.template `
        -Parameters `
        @{ParameterKey="04DBPassword";ParameterValue="Pcxuser122"}, `
        @{ParameterKey="06WebPassword";ParameterValue="Pcxuser122"}, `
        @{ParameterKey="07KeyName";ParameterValue="RobG_id_rsa"}, `
        @{ParameterKey="08RemoteAccessLocation";ParameterValue="103.231.169.65/32"}, `
        @{ParameterKey="11WebServerInstanceTyp";ParameterValue="t2.micro"} | Write-Host
    }
    catch
    {
        $_ | Write-Host
        $ErrorCount++
        Write-Host "Error creating scalable stack in $region"
    }
    Write-Host ("`r")
}

if ( $ErrorCount )
{
    Write-Host "$ErrorCount errors"
}

Write-Host "Wait for stacks to be created and then test they may be browsed to using <url>/cgi-bin/lansaweb?wam=DEPTABWA&webrtn=BuildFirst&ml=LANSA:XHTML&part=DEX&lang=ENG"