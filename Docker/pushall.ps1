param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('base', 'All')]
    [string]
    $LansaImage='All',

    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $ImageVersion = "16.0.0"
)

$Registry="DockerHub"

if ( $Registry -eq 'AWS') {
    Write-Host "Logging in to AWS Docker Repository"
    Invoke-Expression -Command (Get-ECRLoginCommand -Region us-east-1).Command
}

$majorVersion = ($ImageVersion -split '\.')[0]
$ga_tag = "v${majorVersion}ga"

$ImageList = @($LansaImage)
if ($LansaImage -eq 'All' ) {
    $ImageList ='base'
}

if ($DockerLabel -eq 'all' ) {
    $DockerLabel = 'ltsc2025'
}
$LabelList = @()
if (  $Registry -eq 'AWS') {
    # A latest tag must exist first in order to add other tags to AWS Docker Repository
    $LabelList += "latest"
}
$LabelList += "$($ImageVersion)-$($DockerLabel)"
$LabelList += "$($ga_tag)-$($DockerLabel)"

Write-Host "Image List"
$ImageList
Write-Host "Label List"
$LabelList

foreach ($Label in $LabelList ) {
    foreach ($Image in $ImageList ) {
        $ImageBase = "lansalpc/vl$($Image)-servercore"
        if ( $Registry -eq 'DockerHub') {
            Write-Host "Push to Docker Hub Registry"
            # docker push "$($ImageBase):latest"
            docker push "$($ImageBase):$($Label)"
        }
        elseif ( $Registry -eq 'AWS') {
            Write-Host "Re-tag docker image for AWS Docker Repository"
            $NewImageBase = "775488040364.dkr.ecr.us-east-1.amazonaws.com/$ImageBase"
            Write-Host "New tag: $Label"
            Write-Host "Current base: $ImageBase"
            Write-Host "New base: $NewImageBase"
            # A latest tag must exist in order to add other tags
            docker tag "$($ImageBase):$Label" "$($NewImageBase):$Label"

            Write-Host "Push to AWS Docker Registry"
            docker push "$($NewImageBase):$Label"
        }
    }
}



