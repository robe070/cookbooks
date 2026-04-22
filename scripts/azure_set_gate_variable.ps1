param (
    [Parameter(Mandatory=$true)]
    [string]
    $Version,

    [Parameter(Mandatory=$true)]
    [string]
    $osName
   )

Write-Host "version is - $Version"
# Set the Gate variable if the file exists
$path = "$($env:Pipeline_Workspace)/_BuildImageReleaseArtefacts/$Version/$Version.txt"
if (Test-Path $path) {
    # Remove characters from Version so reduce length to less than 9 and which are not compatible with resource ids in the template.
    # In particular, the VM base name in a Scale Set
    $VersionClean = $Version -replace '[-]',''
    # $VersionClean = ""
    # Randomize the Version because its being used as an ID that is causing duplicates if just use the version number.
    1..7 | ForEach {
        $code = Get-Random -Minimum 97 -Maximum 122 # Lower case letters only
        $VersionClean = $VersionClean + [char]$code
    }
    Write-Host "Clean version = $VersionClean"

    $stackname = "$($env:RESOURCEGROUPNAME)-PubImages-$($env:LANSA_JOBNAME)"
    Write-Host "StackName is $stackname"

    $Uri = Get-Content -Path $path -Raw
    Write-Host "ImageUrl is $Uri"
    # Extract the minor version from the ImageUrl string e.g. /subscriptions/739c4e86-bd75-4910-8d6e-d7eb23ab94f3/resourceGroups/BakingDP/providers/Microsoft.Compute/galleries/LansaGallery/images/w25d-16-0/versions/16.0.21
    $versionNumber = ($Uri -split '/versions/')[1]
    $minorVersion = ($versionNumber -split '\.')[2]
    $sku = "$($Version)-$($minorVersion)"
    Write-Host "SKU is $sku"

    Write-Host "##vso[task.setvariable variable=Sku;isOutput=true]$sku"
    # Set Variables
    Write-Host "##vso[task.setvariable variable=StackName;isOutput=true]$stackname"
    Write-Host "##vso[task.setvariable variable=ImageUrl;isOutput=true]$Uri"
    Write-Host "##vso[task.setvariable variable=IsEnabled;isOutput=true]True"
    Write-Host "##vso[task.setvariable variable=osName;isOutput=true]$osName"
    Write-Host "##vso[task.setvariable variable=Version;isOutput=true]$Version"
    Write-Host "##vso[task.setvariable variable=VersionClean;isOutput=true]$VersionClean"
    Write-host "The value of Variable IsEnabled is updated to True and output variable ImageUrl to $Uri and StackName to $stackname"
} else {
    Write-Host "Artifact path does NOT exist for $Version"
}