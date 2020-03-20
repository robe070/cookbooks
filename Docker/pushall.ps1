param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('base', 'vlweb', 'All')]
    [string]
    $LansaImage='All',

    [Parameter(Mandatory=$false)]
    [ValidateSet('1903', '1909', 'ltsc2019', 'All')]
    [string]
    $DockerLabel='1909',

    [Parameter(Mandatory=$false)]
    [string]
    $ImageVersion = "14.99"
)

Write-Host "Logging in to AWS Docker Repository"
Invoke-Expression -Command (Get-ECRLoginCommand -Region us-east-1).Command

$ImageList = @($LansaImage)
if ($LansaImage -eq 'All' ) {
    $ImageList ='base', 'vlweb'
}

$LabelList = @($DockerLabel)
if ($DockerLabel -eq 'All' ) {
    $LabelList = '1903', '1909', 'ltsc2019'
}

Write-Host "Image List"
$ImageList
Write-Host "Label List"
$LabelList
foreach ($Label in $LabelList ) {
    foreach ($Image in $ImageList ) {
        Write-Host "Re-tag docker image for AWS Docker Repository"
        $ImageTag = "$($ImageVersion)-windowsservercore-$Label"
        $ImageBase = "lansalpc/iis/$($Image)"
        $NewImageBase = "775488040364.dkr.ecr.us-east-1.amazonaws.com/$ImageBase"
        Write-Host "New tag: $ImageTag"
        Write-Host "Current base: $ImageBase"
        Write-Host "New base: $NewImageBase"
        # A latest tag must exist in order to add other tags
        docker tag "$($ImageBase):$ImageTag" "$($NewImageBase):latest"
        docker tag "$($ImageBase):$ImageTag" "$($NewImageBase):$ImageTag"

        Write-Host "Push to AWS Docker Repository"
        docker push "$($NewImageBase):latest"
        docker push "$($NewImageBase):$ImageTag"
    }
}
