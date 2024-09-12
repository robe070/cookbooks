param(
    [Parameter(Mandatory=$false)]
    [String]
    $TemplateUrl = 'https://awsmp-fulfillment-cf-templates-prod.s3-external-1.amazonaws.com/f462ff15-792b-412d-b5e6-84640bfb702d/a8668dcd-c1e8-4f70-94ff-205965c6e514/a935c13a5b70498889550e501de68671.template',

    [Parameter(Mandatory=$false)]
    [switch]
    $ActualTemplate,

    [Parameter(Mandatory=$false)]
    [array]
    $RegionsRequested
)

Write-Host( "Requested URL to check is $TemplateUrl")

$ActualUrl = $TemplateUrl

Write-Host( "Default behaviour is to presume that the url provided is the Stack Type template and the Master template url must be derived from within it" )
if ( -not $ActualTemplate ) {
    # Ensures that Invoke-WebRequest uses TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $TemplateJson = Invoke-WebRequest $TemplateUrl | ConvertFrom-Json

    if ( $TemplateJson ) {
        Write-Host("JSON loaded`n" )

        $ActualUrl = $TemplateJson.Resources.MasterStackApp.Properties.TemplateURL
        Write-Host( "Actual TemplateUrl = $ActualUrl" )
    } else {
        throw "Error loading $(TemplateUrl)"
    }

}

if ( $RegionsRequested ) {
    Write-Host("Check that AMIs in $ActualUrl for Regions $RegionsRequested are valid")
} else {
    Write-Host("Check that all AMIs in $ActualUrl are valid for all regions")
}

# Ensures that Invoke-WebRequest uses TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TemplateJson = Invoke-WebRequest $ActualUrl | ConvertFrom-Json

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
        foreach ($win in @("win2016", "win2019","win2016jpn", "win2019jpn")) {
            $First = $true
            $AMIList = @()
            # Check whether an AMI exists in the template for this Region/Win version
            if ( Get-Member -inputobject $AMI142 -name "$Region") {
                if ( Get-Member -inputobject $AMI142.$Region -name "$win") {
                    $AMIList += $AMI142.$Region.$win
                } else {
                    Write-Host( "                      $win V14.2 The template has no AMI for $win")
                }
            } else {
                Write-Host( "                      $win V14.2 The template has no AMI in $Region")
            }
            if ( Get-Member -inputobject $AMI15 -name "$Region" ) {
                if ( Get-Member -inputobject $AMI15.$Region -name "$win") {
                    $AMIList += $AMI15.$Region.$win
                } else {
                    Write-Host( "                      $win V15   The template has no AMI for $win")
                }
            } else {
                Write-Host( "                      $win V15   The template has no AMI in $Region")
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

                $Spacing = "   "
                if ( $win -eq "win2016jpn" -or ($win -eq "win2019jpn") ) {
                    $Spacing = ""
                }

                if ( $First) {
                    Write-Host( "$AMI $win $Spacing V14.2 $Result")
                } else {
                    Write-Host( "$AMI $win $Spacing V15   $Result")
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

Write-Host( "All AMIs in the template are accessible in the appropriate region")