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

function New-RunXml {
    param(
        [AllowNull()]
        [string]$Text,
        [switch]$Code,
        [switch]$Bold,
        [switch]$Italic,
        [string]$FontSize,
        [string]$Color
    )

    $properties = New-Object System.Collections.Generic.List[string]
    if ($Code) {
        $properties.Add('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>')
    }
    if ($Bold) {
        $properties.Add('<w:b/>')
    }
    if ($Italic) {
        $properties.Add('<w:i/>')
    }
    if ($FontSize) {
        $properties.Add('<w:sz w:val="' + (Escape-Xml $FontSize) + '"/>')
    }
    if ($Color) {
        $properties.Add('<w:color w:val="' + (Escape-Xml $Color) + '"/>')
    }

    $rPr = ''
    if ($properties.Count -gt 0) {
        $rPr = '<w:rPr>' + ($properties -join '') + '</w:rPr>'
    }

    return '<w:r>' + $rPr + '<w:t xml:space="preserve">' + (Escape-Xml $Text) + '</w:t></w:r>'
}

function Get-InlineRunXml {
    param(
        [string]$Text,
        [switch]$DefaultBold
    )

    $parts = $Text -split '`', -1
    $runs = New-Object System.Collections.Generic.List[string]
    $boldPattern = '\*\*([^*](?:.*?[^*])?)\*\*'

    for ($index = 0; $index -lt $parts.Length; $index++) {
        if ($index % 2 -eq 1) {
            $runs.Add((New-RunXml -Text $parts[$index] -Code))
            continue
        }

        $position = 0
        foreach ($match in [regex]::Matches($parts[$index], $boldPattern)) {
            if ($match.Index -gt $position) {
                $runs.Add((New-RunXml -Text $parts[$index].Substring($position, $match.Index - $position) -Bold:$DefaultBold))
            }

            $runs.Add((New-RunXml -Text $match.Groups[1].Value -Bold))
            $position = $match.Index + $match.Length
        }

        if ($position -lt $parts[$index].Length) {
            $runs.Add((New-RunXml -Text $parts[$index].Substring($position) -Bold:$DefaultBold))
        }
    }

    if ($runs.Count -eq 0) {
        $runs.Add((New-RunXml -Text '' -Bold:$DefaultBold))
    }

    return ($runs -join '')
}

function New-ParagraphXml {
    param(
        [AllowNull()]
        [string]$Text,
        [string]$Style,
        [string]$RunsXml,
        [switch]$Bullet,
        [int]$IndentTwips = 0,
        [string[]]$ParagraphProperties
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

    foreach ($property in $ParagraphProperties) {
        if (-not [string]::IsNullOrWhiteSpace($property)) {
            $properties.Add($property)
        }
    }

    $pPr = ''
    if ($properties.Count -gt 0) {
        $pPr = '<w:pPr>' + ($properties -join '') + '</w:pPr>'
    }

    if (-not $RunsXml) {
        $RunsXml = Get-InlineRunXml -Text $Text
    }

    return '<w:p>' + $pPr + $RunsXml + '</w:p>'
}

function New-CodeParagraphXml {
    param(
        [string]$RunsXml
    )

    return '<w:p><w:pPr><w:pStyle w:val="CodeBlock"/></w:pPr>' + $RunsXml + '</w:p>'
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

function New-HorizontalRuleXml {
    return '<w:p><w:pPr><w:spacing w:before="120" w:after="120"/><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="BFBFBF"/></w:pBdr></w:pPr></w:p>'
}

function Split-MarkdownTableRow {
    param(
        [string]$Line
    )

    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith('|')) {
        $trimmed = $trimmed.Substring(1)
    }
    if ($trimmed.EndsWith('|')) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - 1)
    }

    return @($trimmed -split '\|' | ForEach-Object { $_.Trim() })
}

function Test-MarkdownTableSeparator {
    param(
        [string]$Line
    )

    $cells = Split-MarkdownTableRow -Line $Line
    if ($cells.Count -eq 0) {
        return $false
    }

    foreach ($cell in $cells) {
        if ($cell -notmatch '^:?-{3,}:?$') {
            return $false
        }
    }

    return $true
}

function Get-MarkdownTableAlignments {
    param(
        [string]$SeparatorLine
    )

    $alignments = New-Object System.Collections.Generic.List[string]
    foreach ($cell in (Split-MarkdownTableRow -Line $SeparatorLine)) {
        switch -Regex ($cell) {
            '^:-{3,}:$' { $alignments.Add('center'); continue }
            '^-{3,}:$' { $alignments.Add('right'); continue }
            '^:-{3,}$' { $alignments.Add('left'); continue }
            default { $alignments.Add('left') }
        }
    }

    return ,$alignments.ToArray()
}

function New-TableCellParagraphXml {
    param(
        [string]$Text,
        [string]$Alignment = 'left',
        [switch]$Header
    )

    $paragraphProperties = @()
    if ($Alignment -eq 'center' -or $Alignment -eq 'right') {
        $paragraphProperties += '<w:jc w:val="' + $Alignment + '"/>'
    }

    $runs = Get-InlineRunXml -Text $Text -DefaultBold:$Header
    return New-ParagraphXml -RunsXml $runs -ParagraphProperties $paragraphProperties
}

function New-MarkdownTableXml {
    param(
        [string[]]$HeaderCells,
        [string[]]$Alignments,
        [System.Collections.Generic.List[string[]]]$Rows
    )

    $columnCount = [Math]::Max($HeaderCells.Count, $Alignments.Count)
    if ($columnCount -le 0) {
        throw 'Cannot build a table with zero columns.'
    }

    $cellWidth = [int]([Math]::Floor(9000 / $columnCount))
    $gridColumns = for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
        '<w:gridCol w:w="' + $cellWidth + '"/>'
    }

    $rowXml = New-Object System.Collections.Generic.List[string]

    $headerCellsXml = New-Object System.Collections.Generic.List[string]
    for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
        $text = if ($columnIndex -lt $HeaderCells.Count) { $HeaderCells[$columnIndex] } else { '' }
        $alignment = if ($columnIndex -lt $Alignments.Count) { $Alignments[$columnIndex] } else { 'left' }
        $paragraph = New-TableCellParagraphXml -Text $text -Alignment $alignment -Header
        $headerCellsXml.Add('<w:tc><w:tcPr><w:tcW w:w="' + $cellWidth + '" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="D9EAF7"/></w:tcPr>' + $paragraph + '</w:tc>')
    }
    $rowXml.Add('<w:tr>' + ($headerCellsXml -join '') + '</w:tr>')

    foreach ($row in $Rows) {
        $cellXml = New-Object System.Collections.Generic.List[string]
        for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
            $text = if ($columnIndex -lt $row.Count) { $row[$columnIndex] } else { '' }
            $alignment = if ($columnIndex -lt $Alignments.Count) { $Alignments[$columnIndex] } else { 'left' }
            $paragraph = New-TableCellParagraphXml -Text $text -Alignment $alignment
            $cellXml.Add('<w:tc><w:tcPr><w:tcW w:w="' + $cellWidth + '" w:type="dxa"/></w:tcPr>' + $paragraph + '</w:tc>')
        }
        $rowXml.Add('<w:tr>' + ($cellXml -join '') + '</w:tr>')
    }

    return @"
<w:tbl>
  <w:tblPr>
    <w:tblW w:w="0" w:type="auto"/>
    <w:tblBorders>
      <w:top w:val="single" w:sz="4" w:space="0" w:color="808080"/>
      <w:left w:val="single" w:sz="4" w:space="0" w:color="808080"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="808080"/>
      <w:right w:val="single" w:sz="4" w:space="0" w:color="808080"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="C0C0C0"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="C0C0C0"/>
    </w:tblBorders>
  </w:tblPr>
  <w:tblGrid>
    $($gridColumns -join "`r`n    ")
  </w:tblGrid>
  $($rowXml -join "`r`n  ")
</w:tbl>
"@
}

function Get-PowerShellCodeRunsXml {
    param(
        [string]$Text
    )

    if ($null -eq $Text) {
        return (New-RunXml -Text '' -Code)
    }

    $runs = New-Object System.Collections.Generic.List[string]
    $keywordPattern = '^(?i:(?:begin|break|catch|class|continue|data|do|dynamicparam|else|elseif|end|enum|exit|filter|finally|for|foreach|from|function|if|in|param|process|return|switch|throw|trap|try|until|using|var|while))\b'
    $variablePattern = '^\$[A-Za-z_][\w:.\-]*'
    $parameterPattern = '^-{1,2}[A-Za-z][\w\-]*'
    $position = 0

    while ($position -lt $Text.Length) {
        $remaining = $Text.Substring($position)
        $currentChar = $Text[$position]

        if ($currentChar -eq '#') {
            $runs.Add((New-RunXml -Text $remaining -Code -Color '008000'))
            break
        }

        if ($currentChar -eq '"' -or $currentChar -eq "'") {
            $quote = $currentChar
            $end = $position + 1
            while ($end -lt $Text.Length) {
                if ($Text[$end] -eq $quote) {
                    if ($quote -eq "'" -and $end + 1 -lt $Text.Length -and $Text[$end + 1] -eq "'") {
                        $end += 2
                        continue
                    }

                    $end++
                    break
                }

                if ($Text[$end] -eq '`' -and $end + 1 -lt $Text.Length) {
                    $end += 2
                    continue
                }

                $end++
            }

            if ($end -gt $Text.Length) {
                $end = $Text.Length
            }

            $runs.Add((New-RunXml -Text $Text.Substring($position, $end - $position) -Code -Color 'A31515'))
            $position = $end
            continue
        }

        if ($remaining -match $variablePattern) {
            $token = $Matches[0]
            $runs.Add((New-RunXml -Text $token -Code -Color '267F99'))
            $position += $token.Length
            continue
        }

        if ($remaining -match $parameterPattern) {
            $token = $Matches[0]
            $runs.Add((New-RunXml -Text $token -Code -Color '795E26'))
            $position += $token.Length
            continue
        }

        if ($remaining -match $keywordPattern) {
            $token = $Matches[0]
            $runs.Add((New-RunXml -Text $token -Code -Color '0000FF'))
            $position += $token.Length
            continue
        }

        $next = $position + 1
        while ($next -lt $Text.Length) {
            $candidate = $Text.Substring($next)
            $nextChar = $Text[$next]
            if ($nextChar -eq '#' -or $nextChar -eq '"' -or $nextChar -eq "'" -or $candidate -match $variablePattern -or $candidate -match $parameterPattern -or $candidate -match $keywordPattern) {
                break
            }
            $next++
        }

        $runs.Add((New-RunXml -Text $Text.Substring($position, $next - $position) -Code))
        $position = $next
    }

    if ($runs.Count -eq 0) {
        $runs.Add((New-RunXml -Text '' -Code))
    }

    return ($runs -join '')
}

function New-CodeBlockLineXml {
    param(
        [string]$Text,
        [string]$Language
    )

    $normalizedLanguage = if ($Language) { $Language.ToLowerInvariant() } else { '' }
    $runs = switch ($normalizedLanguage) {
        'powershell' { Get-PowerShellCodeRunsXml -Text $Text }
        'pwsh' { Get-PowerShellCodeRunsXml -Text $Text }
        'ps1' { Get-PowerShellCodeRunsXml -Text $Text }
        default { New-RunXml -Text $Text -Code }
    }

    return New-CodeParagraphXml -RunsXml $runs
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

    $bodyElements = New-Object System.Collections.Generic.List[string]
    $imageRegistry = @{}
    $nextRelationshipIndex = ($documentRelationshipsXml.Relationships.Relationship | Measure-Object).Count + 1
    $nextImageIndex = 1
    $nextDocPrId = 1
    $insideCodeBlock = $false
    $codeBlockLanguage = ''
    $lines = @(Get-Content -LiteralPath $markdownFullPath)

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]

        if ($line -match '^```(?<lang>[A-Za-z0-9_-]+)?\s*$') {
            if (-not $insideCodeBlock) {
                $insideCodeBlock = $true
                $codeBlockLanguage = if ($Matches['lang']) { $Matches['lang'].ToLowerInvariant() } else { '' }
            }
            else {
                $insideCodeBlock = $false
                $codeBlockLanguage = ''
            }
            continue
        }

        if ($insideCodeBlock) {
            $bodyElements.Add((New-CodeBlockLineXml -Text $line -Language $codeBlockLanguage))
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
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
            $bodyElements.Add((New-ImageParagraphXml -RelationshipId $imageInfo.RelationshipId -ImageName $imageInfo.ImageName -AltText $imageReference.AltText -WidthEmu $imageSize.WidthEmu -HeightEmu $imageSize.HeightEmu -DocPrId $nextDocPrId))
            $nextDocPrId++
            continue
        }

        if ($line.TrimStart().StartsWith('|') -and $lineIndex + 1 -lt $lines.Count -and (Test-MarkdownTableSeparator -Line $lines[$lineIndex + 1])) {
            $headerCells = Split-MarkdownTableRow -Line $line
            $alignments = Get-MarkdownTableAlignments -SeparatorLine $lines[$lineIndex + 1]
            $rows = New-Object 'System.Collections.Generic.List[string[]]'
            $lineIndex += 2

            while ($lineIndex -lt $lines.Count -and $lines[$lineIndex].TrimStart().StartsWith('|')) {
                $rows.Add((Split-MarkdownTableRow -Line $lines[$lineIndex]))
                $lineIndex++
            }

            $bodyElements.Add((New-MarkdownTableXml -HeaderCells $headerCells -Alignments $alignments -Rows $rows))
            $lineIndex--
            continue
        }

        if ($line -match '^\s*(?:---+|\*\*\*+|___+)\s*$') {
            $bodyElements.Add((New-HorizontalRuleXml))
            continue
        }

        if ($line -match '^###### (.+)$') {
            $bodyElements.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading5'))
            continue
        }

        if ($line -match '^##### (.+)$') {
            $bodyElements.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading4'))
            continue
        }

        if ($line -match '^#### (.+)$') {
            $bodyElements.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading3'))
            continue
        }

        if ($line -match '^### (.+)$') {
            $bodyElements.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading2'))
            continue
        }

        if ($line -match '^## (.+)$') {
            $bodyElements.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading1'))
            continue
        }

        if ($line -match '^# (.+)$') {
            $bodyElements.Add((New-ParagraphXml -Text $Matches[1] -Style 'Title'))
            continue
        }

        if ($line -match '^\s*-\s+(.+)$') {
            $bodyElements.Add((New-ParagraphXml -Text $Matches[1] -Bullet))
            continue
        }

        $bodyElements.Add((New-ParagraphXml -Text $line))
    }

    $documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
$documentOpenTag
  <w:body>
    $($bodyElements -join "`r`n    ")
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
