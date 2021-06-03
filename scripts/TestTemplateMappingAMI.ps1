param(
    [Parameter(Mandatory=$false)]
    [String]
    $TemplateUrl = 'http://awsmp-fulfillment-cf-templates-prod.s3.amazonaws.com/6724eab5-8d5f-425c-9270-357e7aaaa9ae/7390b444-261d-48bd-8d2c-eb4c7d8fb0d2/c13f8f1d95ab4f738f23462def221275.template',

    [Parameter(Mandatory=$false)]
    [array]
    $RegionsRequested
)

if ( $RegionsRequested ) {
    Write-Host("Check that AMIs in $TemplateUrl for Regions $RegionsRequested are valid")
} else {
    Write-Host("Check that all AMIs in $TemplateUrl are valid for all regions")
}

# Ensures that Invoke-WebRequest uses TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TemplateJson = Invoke-WebRequest $TemplateUrl | ConvertFrom-Json

if ( $TemplateJson ) {
    Write-Host("JSON loaded`n" )

    $Failures = 0

    #$TemplateJson
    $AMI142 = $TemplateJson.Mappings.AWSRegionArch2AMI142

    Write-Host( "V14 SP2 AMIs")
    $AMI142 | Out-Default | Write-Host

    $AMI15 = $TemplateJson.Mappings.AWSRegionArch2AMI15
    Write-Host( "V15 GA AMIs")
    $AMI15 | Out-Default | Write-Host

    if ( $RegionsRequested ) {
        $Regions = @($RegionsRequested)
    } else {
        $Regions = Get-AWSRegion
    }
    foreach ($Region in $Regions) {
        Write-Host("$Region")
        foreach ($win in @("win2012", "win2016", "win2019")) {
            $First = $true
            $AMIList = @()
            # Check whether an AMI exists in the template for this Region/Win version
            if ( Get-Member -inputobject $AMI142 -name "$Region") {
                if ( Get-Member -inputobject $AMI142.$Region -name "$win") {
                    $AMIList += $AMI142.$Region.$win
                } else {
                    Write-Host( "                      $win V14.2 There is no AMI for $win")
                }
            } else {
                Write-Host( "                      $win V14.2 There is no AMI in $Region")
            }
            if ( Get-Member -inputobject $AMI15 -name "$Region" ) {
                if ( Get-Member -inputobject $AMI15.$Region -name "$win") {
                    $AMIList += $AMI15.$Region.$win
                } else {
                    Write-Host( "                      $win V15   There is no AMI for $win")
                }
            } else {
                Write-Host( "                      $win V15   There is no AMI in $Region")
            }
            foreach( $AMI in $AMIList) {
                try {
                    $Result = "Failed"
                    $AMIDetails = Get-Ec2Image $AMI -Region $Region -ErrorAction SilentlyContinue
                    if ($AMIDetails){
                        $Result = "Success"
                    } else {
                        $Failures += 1
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
        Write-Host( "`n")
    }
    if ( $Failures -gt 0 ) {
        throw "There have been $(Failures) failures in $(TemplateUrl)"
    }
} else {
    throw "Error loading $(TemplateUrl)"
}
