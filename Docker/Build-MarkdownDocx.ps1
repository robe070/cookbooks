[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,

    [Parameter(Mandatory = $true)]
    [string]$DocxPath,

    [string]$TemplateRoot = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TemplatePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $path = Join-Path $TemplateRoot $Name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Template file not found: $path"
    }

    return (Resolve-Path -LiteralPath $path).Path
}

function Escape-Xml {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape($Text)
}

function Get-InlineRunXml {
    param(
        [string]$Text
    )

    $parts = $Text -split '`', -1
    $runs = New-Object System.Collections.Generic.List[string]

    for ($index = 0; $index -lt $parts.Length; $index++) {
        $escaped = Escape-Xml $parts[$index]
        if ($index % 2 -eq 1) {
            $runs.Add('<w:r><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/></w:rPr><w:t xml:space="preserve">' + $escaped + '</w:t></w:r>')
        }
        else {
            $runs.Add('<w:r><w:t xml:space="preserve">' + $escaped + '</w:t></w:r>')
        }
    }

    if ($runs.Count -eq 0) {
        $runs.Add('<w:r><w:t xml:space="preserve"></w:t></w:r>')
    }

    return ($runs -join '')
}

function New-ParagraphXml {
    param(
        [AllowNull()]
        [string]$Text,
        [string]$Style,
        [switch]$CodeBlock,
        [switch]$Bullet,
        [int]$IndentTwips = 0
    )

    $properties = New-Object System.Collections.Generic.List[string]
    if ($Style) {
        $properties.Add('<w:pStyle w:val="' + (Escape-Xml $Style) + '"/>')
    }

    if ($Bullet) {
        if ($IndentTwips -le 0) {
            $IndentTwips = 720
        }
        $properties.Add('<w:ind w:left="' + $IndentTwips + '" w:hanging="360"/>')
        $Text = [string]::Concat([char]0x2022, ' ', $Text)
    }
    elseif ($IndentTwips -gt 0) {
        $properties.Add('<w:ind w:left="' + $IndentTwips + '"/>')
    }

    $pPr = ''
    if ($properties.Count -gt 0) {
        $pPr = '<w:pPr>' + ($properties -join '') + '</w:pPr>'
    }

    if ($CodeBlock) {
        $runs = '<w:r><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">' + (Escape-Xml $Text) + '</w:t></w:r>'
    }
    else {
        $runs = Get-InlineRunXml -Text $Text
    }

    return '<w:p>' + $pPr + $runs + '</w:p>'
}

function Get-HtmlAttributeValue {
    param(
        [string]$Attributes,
        [string]$Name
    )

    $match = [regex]::Match($Attributes, '\b' + [regex]::Escape($Name) + '\s*=\s*(?:"([^"]*)"|''([^'']*)'')', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        return $null
    }

    if ($match.Groups[1].Success) {
        return $match.Groups[1].Value
    }

    return $match.Groups[2].Value
}

function Get-MarkdownImageReference {
    param(
        [string]$Line
    )

    $markdownMatch = [regex]::Match($Line, '^\s*!\[(?<alt>[^\]]*)\]\((?<target>.+)\)\s*$')
    if ($markdownMatch.Success) {
        $target = $markdownMatch.Groups['target'].Value.Trim()
        if ($target.StartsWith('<') -and $target.EndsWith('>')) {
            $target = $target.Substring(1, $target.Length - 2)
        }
        elseif ($target -match '^(?<path>.+?)\s+("(?:[^"]*)"|''(?:[^'']*)'')\s*$') {
            $target = $Matches['path'].Trim()
        }

        return [pscustomobject]@{
            AltText = $markdownMatch.Groups['alt'].Value
            Path = $target
            WidthPx = $null
        }
    }

    $htmlMatch = [regex]::Match($Line, '^\s*<img\b(?<attrs>[^>]*)/?>\s*$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($htmlMatch.Success) {
        $attributes = $htmlMatch.Groups['attrs'].Value
        $src = Get-HtmlAttributeValue -Attributes $attributes -Name 'src'
        if ([string]::IsNullOrWhiteSpace($src)) {
            return $null
        }

        $widthText = Get-HtmlAttributeValue -Attributes $attributes -Name 'width'
        $widthPx = $null
        if ($widthText -and ($widthText -match '^\d+$')) {
            $widthPx = [int]$widthText
        }

        return [pscustomobject]@{
            AltText = (Get-HtmlAttributeValue -Attributes $attributes -Name 'alt')
            Path = $src.Trim()
            WidthPx = $widthPx
        }
    }

    return $null
}

function Resolve-MarkdownAssetPath {
    param(
        [string]$BaseDirectory,
        [string]$AssetPath
    )

    $candidate = $AssetPath.Trim()
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        throw 'Image path is empty.'
    }

    if ([System.IO.Path]::IsPathRooted($candidate)) {
        $resolved = $candidate
    }
    else {
        $resolved = Join-Path $BaseDirectory $candidate
    }

    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "Image file not found: $resolved"
    }

    return (Resolve-Path -LiteralPath $resolved).Path
}

function Get-ImageContentType {
    param(
        [string]$Extension
    )

    switch ($Extension.ToLowerInvariant()) {
        '.png' { return 'image/png' }
        '.jpg' { return 'image/jpeg' }
        '.jpeg' { return 'image/jpeg' }
        '.gif' { return 'image/gif' }
        '.bmp' { return 'image/bmp' }
        '.tif' { return 'image/tiff' }
        '.tiff' { return 'image/tiff' }
        default { throw "Unsupported image type: $Extension" }
    }
}

function Add-ContentTypeDefault {
    param(
        [xml]$Xml,
        [string]$Extension,
        [string]$ContentType
    )

    foreach ($node in $Xml.Types.Default) {
        if ($node.Extension -eq $Extension) {
            return
        }
    }

    $defaultNode = $Xml.CreateElement('Default', $Xml.DocumentElement.NamespaceURI)
    [void]$defaultNode.SetAttribute('Extension', $Extension)
    [void]$defaultNode.SetAttribute('ContentType', $ContentType)
    [void]$Xml.Types.AppendChild($defaultNode)
}

function Add-DocumentRelationship {
    param(
        [xml]$Xml,
        [string]$Id,
        [string]$Type,
        [string]$Target
    )

    $relationshipNode = $Xml.CreateElement('Relationship', $Xml.DocumentElement.NamespaceURI)
    [void]$relationshipNode.SetAttribute('Id', $Id)
    [void]$relationshipNode.SetAttribute('Type', $Type)
    [void]$relationshipNode.SetAttribute('Target', $Target)
    [void]$Xml.DocumentElement.AppendChild($relationshipNode)
}

function Get-ImageSizing {
    param(
        [string]$Path,
        [Nullable[int]]$RequestedWidthPx
    )

    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        if ($image.Width -le 0 -or $image.Height -le 0) {
            throw "Image has invalid dimensions: $Path"
        }

        $maxWidthPx = 624.0
        $targetWidthPx = if ($null -ne $RequestedWidthPx) { [double]$RequestedWidthPx } else { [double]$image.Width }
        if ($targetWidthPx -gt $maxWidthPx) {
            $targetWidthPx = $maxWidthPx
        }

        $scale = $targetWidthPx / [double]$image.Width
        $targetHeightPx = [Math]::Round([double]$image.Height * $scale)
        $targetWidthPx = [Math]::Round($targetWidthPx)

        return [pscustomobject]@{
            WidthEmu = [long]([Math]::Round($targetWidthPx * 9525.0))
            HeightEmu = [long]([Math]::Round($targetHeightPx * 9525.0))
        }
    }
    finally {
        $image.Dispose()
    }
}

function New-ImageParagraphXml {
    param(
        [string]$RelationshipId,
        [string]$ImageName,
        [string]$AltText,
        [long]$WidthEmu,
        [long]$HeightEmu,
        [int]$DocPrId
    )

    $escapedName = Escape-Xml $ImageName
    $escapedAlt = Escape-Xml $AltText

    return @"
<w:p>
  <w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$WidthEmu" cy="$HeightEmu"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="$DocPrId" name="$escapedName" descr="$escapedAlt"/>
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks noChangeAspect="1"/>
        </wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="$escapedName" descr="$escapedAlt"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$RelationshipId"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="$WidthEmu" cy="$HeightEmu"/>
                </a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"@
}

$markdownFullPath = (Resolve-Path -LiteralPath $MarkdownPath).Path
$docxFullPath = [System.IO.Path]::GetFullPath($DocxPath)
$markdownDirectory = Split-Path -Path $markdownFullPath -Parent
$docxDirectory = Split-Path -Path $docxFullPath -Parent
if (-not (Test-Path -LiteralPath $docxDirectory)) {
    New-Item -ItemType Directory -Path $docxDirectory | Out-Null
}

$contentTypesTemplate = Get-TemplatePath -Name 'docx-template-content-types.xml'
$packageRelsTemplate = Get-TemplatePath -Name 'docx-template-package-rels.xml'
$wordStylesTemplate = Get-TemplatePath -Name 'docx-template-word-styles.xml'
$documentRelsTemplate = Get-TemplatePath -Name 'docx-template-word-document-rels.xml'
$documentTemplate = Get-TemplatePath -Name 'docx-template-word-document.xml'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('docx-build-' + [guid]::NewGuid().ToString('N'))
$zipPath = [System.IO.Path]::ChangeExtension($docxFullPath, '.zip')

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot '_rels') | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'word') | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'word\_rels') | Out-Null
    $mediaDirectory = Join-Path $tempRoot 'word\media'
    New-Item -ItemType Directory -Path $mediaDirectory | Out-Null

    Copy-Item -LiteralPath $packageRelsTemplate -Destination (Join-Path $tempRoot '_rels\.rels')
    Copy-Item -LiteralPath $wordStylesTemplate -Destination (Join-Path $tempRoot 'word\styles.xml')

    [xml]$contentTypesXml = Get-Content -LiteralPath $contentTypesTemplate -Raw
    [xml]$documentRelationshipsXml = Get-Content -LiteralPath $documentRelsTemplate -Raw

    $templateXml = Get-Content -LiteralPath $documentTemplate -Raw
    $documentOpenMatch = [regex]::Match($templateXml, '<w:document\b[^>]*>')
    if (-not $documentOpenMatch.Success) {
        throw 'Could not locate <w:document> root element in template.'
    }

    $sectPrMatch = [regex]::Match($templateXml, '<w:sectPr[\s\S]*?</w:sectPr>')
    if (-not $sectPrMatch.Success) {
        throw 'Could not locate <w:sectPr> in template.'
    }

    $documentOpenTag = $documentOpenMatch.Value
    $sectPr = $sectPrMatch.Value

    $paragraphs = New-Object System.Collections.Generic.List[string]
    $imageRegistry = @{}
    $nextRelationshipIndex = ($documentRelationshipsXml.Relationships.Relationship | Measure-Object).Count + 1
    $nextImageIndex = 1
    $nextDocPrId = 1
    $insideCodeBlock = $false

    foreach ($line in (Get-Content -LiteralPath $markdownFullPath)) {
        if ($line -match '^```') {
            $insideCodeBlock = -not $insideCodeBlock
            continue
        }

        if ($insideCodeBlock) {
            $paragraphs.Add((New-ParagraphXml -Text $line -CodeBlock -IndentTwips 360))
            continue
        }

        $imageReference = Get-MarkdownImageReference -Line $line
        if ($null -ne $imageReference) {
            $resolvedImagePath = Resolve-MarkdownAssetPath -BaseDirectory $markdownDirectory -AssetPath $imageReference.Path
            $registryKey = $resolvedImagePath.ToLowerInvariant()

            if (-not $imageRegistry.ContainsKey($registryKey)) {
                $extension = [System.IO.Path]::GetExtension($resolvedImagePath)
                $contentType = Get-ImageContentType -Extension $extension
                $imageName = 'image{0}{1}' -f $nextImageIndex, $extension.ToLowerInvariant()
                $relationshipId = 'rId{0}' -f $nextRelationshipIndex
                $targetPath = Join-Path $mediaDirectory $imageName

                Copy-Item -LiteralPath $resolvedImagePath -Destination $targetPath
                Add-ContentTypeDefault -Xml $contentTypesXml -Extension $extension.TrimStart('.') -ContentType $contentType
                Add-DocumentRelationship -Xml $documentRelationshipsXml -Id $relationshipId -Type 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image' -Target ('media/' + $imageName)

                $imageRegistry[$registryKey] = [pscustomobject]@{
                    RelationshipId = $relationshipId
                    ImageName = $imageName
                    SourcePath = $resolvedImagePath
                }

                $nextImageIndex++
                $nextRelationshipIndex++
            }

            $imageInfo = $imageRegistry[$registryKey]
            $imageSize = Get-ImageSizing -Path $imageInfo.SourcePath -RequestedWidthPx $imageReference.WidthPx
            $paragraphs.Add((New-ImageParagraphXml -RelationshipId $imageInfo.RelationshipId -ImageName $imageInfo.ImageName -AltText $imageReference.AltText -WidthEmu $imageSize.WidthEmu -HeightEmu $imageSize.HeightEmu -DocPrId $nextDocPrId))
            $nextDocPrId++
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            $paragraphs.Add('<w:p/>')
            continue
        }

        if ($line -match '^# (.+)$') {
            $paragraphs.Add((New-ParagraphXml -Text $Matches[1] -Style 'Title'))
            continue
        }

        if ($line -match '^## (.+)$') {
            $paragraphs.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading1'))
            continue
        }

        if ($line -match '^### (.+)$') {
            $paragraphs.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading2'))
            continue
        }

        if ($line -match '^- (.+)$') {
            $paragraphs.Add((New-ParagraphXml -Text $Matches[1] -Bullet))
            continue
        }

        $paragraphs.Add((New-ParagraphXml -Text $line))
    }

    $documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
$documentOpenTag
  <w:body>
    $($paragraphs -join "`r`n    ")
    $sectPr
  </w:body>
</w:document>
"@

    Set-Content -LiteralPath (Join-Path $tempRoot 'word\document.xml') -Value $documentXml -Encoding UTF8
    $contentTypesXml.Save((Join-Path $tempRoot '[Content_Types].xml'))
    $documentRelationshipsXml.Save((Join-Path $tempRoot 'word\_rels\document.xml.rels'))

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    if (Test-Path -LiteralPath $docxFullPath) {
        Remove-Item -LiteralPath $docxFullPath -Force
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempRoot, $zipPath)
    Move-Item -LiteralPath $zipPath -Destination $docxFullPath
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
}
