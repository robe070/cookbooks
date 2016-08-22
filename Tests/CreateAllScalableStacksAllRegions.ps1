<#
.SYNOPSIS

Create a single LANSA Stack in every region so it may be tested in browser.

.EXAMPLE


#>

$ErrorCount = 0
$regionlist = Get-AWSRegion
ForEach ( $region in $regionList )
{
    Write-Output "Region $region"

    try
    {
        Write-Output "$InstanceType"
        New-CFNStack -region $region `
        -StackName "Scalable" `
        -DisableRollback $True `
        -Capability CAPABILITY_IAM `
        -templateURL https://s3-ap-southeast-2.amazonaws.com/lansa/templates/support/L4W14000_scalable/lansa-master-win.cfn.template `
        -Parameters `
        @{ParameterKey="01LansaMSI";ParameterValue=" 	https://s3-ap-southeast-2.amazonaws.com/lansa/app/Test/AWAM132_v1.0.0_en-us.msi"}, `
        @{ParameterKey="04DBPassword";ParameterValue="Pcxuser122"}, `
        @{ParameterKey="06WebPassword";ParameterValue="Pcxuser122"}, `
        @{ParameterKey="07KeyName";ParameterValue="RobG_id_rsa"}, `
        @{ParameterKey="08RemoteAccessLocation";ParameterValue="103.231.159.65/32"}, `
        @{ParameterKey="11WebServerInstanceTyp";ParameterValue="t2.micro"}
    }    
    catch
    {
        $_ | Write-Error 
        $ErrorCount++
        Write-Output "Error creating scalable stack in $region"
    }
}

if ( $ErrorCount )
{
    Write-Output "$ErrorCount errors"
}

Write-Output "Wait for stacks to be created and then test they may be browsed to using <url>/cgi-bin/lansaweb?wam=DEPTABWA&webrtn=BuildFirst&ml=LANSA:XHTML&part=DEX&lang=ENG"