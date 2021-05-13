param(
    [Parameter(Mandatory=$false)]
    [String]
    $TemplateUrl = 'http://awsmp-fulfillment-cf-templates-prod.s3.amazonaws.com/6724eab5-8d5f-425c-9270-357e7aaaa9ae/7390b444-261d-48bd-8d2c-eb4c7d8fb0d2/c13f8f1d95ab4f738f23462def221275.template',

    [Parameter(Mandatory=$false)]
    [String]
    $RegionRequested
)

if ( $RegionRequested ) {
    Write-Host("Check that AMIs in $TemplateUrl for Region $Region are valid")
} else {
    Write-Host("Check that all AMIs in $TemplateUrl are valid for all regions")
}

# Ensures that Invoke-WebRequest uses TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TemplateJson = Invoke-WebRequest $TemplateUrl | ConvertFrom-Json

if ( $TemplateJson ) {
    Write-Host("JSON loaded`n" )
    #$TemplateJson
    $AMI142 = $TemplateJson.Mappings.AWSRegionArch2AMI142
    Write-Host( "V14 SP2 AMIs")
    $AMI142 | Out-Default | Write-Host

    $AMI15 = $TemplateJson.Mappings.AWSRegionArch2AMI15
    Write-Host( "V15 GA AMIs")
    $AMI15 | Out-Default | Write-Host

    if ( $RegionRequested ) {
        $Regions = @($RegionRequested)
    } else {
        $Regions = Get-AWSRegion
    }
    foreach ($Region in $Regions) {
        foreach ( $OmitRegion in @("us-iso-east-1", "us-isob-east-1")) {
            $SkipRegion = $false
            if ( $OmitRegion -eq $region) {
                $SkipRegion = $true
                Break
            }
        }
        if ( $SkipRegion ) {
            Write-Host( "$Region Skipped")
        } else {
            Write-Host("$Region")
            foreach ($win in @("win2012", "win2016", "win2019")) {
                $First = $true
                foreach( $AMI in @($AMI142.$Region.$win, $AMI15.$Region.$win)) {
                    try {
                        $Result = "Failed"
                        $AMIDetails = Get-Ec2Image $AMI -Region $Region -ErrorAction SilentlyContinue
                        if ($AMIDetails){
                            $Result = "Success"
                        }
                    } catch {}

                    if ( $First) {
                        Write-Host( "$AMI $win V14.2 $Result")
                    } else {
                        Write-Host( "$AMI $win V15   $Result")
                    }
                    $First = $false
                }
            }
        }
        Write-Host( "`n")
    }
}
