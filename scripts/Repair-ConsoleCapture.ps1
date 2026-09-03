<#
.SYNOPSIS
    Repairs a console/terminal capture that has mojibake and space-padded line breaks.

.DESCRIPTION
    Applies two INDEPENDENT transformations to a captured console log:

    1. Encoding repair. Console captures on a Japanese (or other non-Latin) Windows
       host are often written as legacy ANSI codepage bytes -- CP932 / Shift-JIS by
       default -- but get read back as Latin-1, producing mojibake such as
       "___s_|___V_[" where "実行ポリシー" was intended. The file is decoded with the
       true source codepage and rewritten as UTF-8.

       Side effect: this also removes spurious NEL (U+0085) line breaks. A CP932 lead
       byte of 0x85 is misread as a Unicode NEL terminator by tools that assume
       Latin-1, splitting one logical line into two. Correct decoding rejoins them.

    2. Reflow of space-padded lines. Some captures lose their newlines and instead pad
       each console row out to the buffer width with literal ASCII spaces, collapsing
       hundreds of rows into a single enormous line. This is a pure-ASCII defect and is
       NOT fixed by the encoding repair -- it needs its own pass.

       Only lines that exceed -MinLineLength AND contain a run of -MinSpaceRun or more
       spaces are split, so genuinely long single-record lines (IIS W3SVC logs, JSON,
       stack traces) and legitimately column-aligned output (git diffstat, Format-Table,
       Get-ItemProperty dumps) are left untouched.

.PARAMETER Path
    One or more capture files to repair. Accepts pipeline input and wildcards.

.PARAMETER SourceEncoding
    Codepage the file was actually written in. Default 932 (Shift-JIS / Japanese ANSI).
    Common alternatives: 936 Simplified Chinese, 949 Korean, 950 Traditional Chinese,
    1252 Western European. Pass 0 to skip the encoding repair entirely.

.PARAMETER MinLineLength
    Only lines longer than this are considered for reflow. Default 150. Raise it if the
    capture has long but legitimate wide-format output.

.PARAMETER MinSpaceRun
    A run of at least this many consecutive spaces is treated as a lost newline.
    Default 3. Two is too aggressive -- it breaks "Name  : value" style output.

.PARAMETER NoBackup
    Skip writing the .bak sidecar. Not recommended.

.PARAMETER NoBom
    Write UTF-8 without a byte-order mark. Default is to include one, which makes
    Notepad and other Windows tools detect the encoding reliably.

.EXAMPLE
    .\Repair-ConsoleCapture.ps1 -Path '.\powershell_20260903.txt'

.EXAMPLE
    Get-ChildItem .\captures\*.txt | .\Repair-ConsoleCapture.ps1 -WhatIf

.EXAMPLE
    # Korean host, and the capture wrapped at a 200-column buffer
    .\Repair-ConsoleCapture.ps1 -Path .\log.txt -SourceEncoding 949 -MinLineLength 200

.NOTES
    Idempotent: a file already carrying a UTF-8 BOM is not re-decoded, so re-running is
    safe. Reflow is naturally idempotent because split output has no padding left.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string[]] $Path,

    [ValidateRange(0, 65535)]
    [int] $SourceEncoding = 932,

    [ValidateRange(1, [int]::MaxValue)]
    [int] $MinLineLength = 150,

    [ValidateRange(2, 100)]
    [int] $MinSpaceRun = 3,

    [switch] $NoBackup,

    [switch] $NoBom
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # .NET Core dropped the legacy codepages from the default provider; register them.
    if ($PSVersionTable.PSEdition -eq 'Core') {
        try {
            [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
        } catch {
            # Already registered, or running somewhere it is not needed.
        }
    }

    $utf8Bom = [byte[]](0xEF, 0xBB, 0xBF)
    $padPattern = " {$MinSpaceRun,}"

    # Segments of a reflowed line are trimmed, which strips the single leading space that
    # git porcelain output carries. Restore it so recovered lines match intact ones.
    $gitModeLine = '^(create|delete|rename) mode '
}

process {
    foreach ($item in (Resolve-Path -Path $Path)) {

        $file = $item.ProviderPath
        Write-Verbose "Processing $file"

        $bytes = [System.IO.File]::ReadAllBytes($file)
        if ($bytes.Length -eq 0) {
            Write-Warning "Skipping empty file: $file"
            continue
        }

        # ---- Stage 1: decode -------------------------------------------------------
        $hasBom = $bytes.Length -ge 3 -and
                  $bytes[0] -eq $utf8Bom[0] -and
                  $bytes[1] -eq $utf8Bom[1] -and
                  $bytes[2] -eq $utf8Bom[2]

        if ($hasBom -or $SourceEncoding -eq 0) {
            $reason = if ($hasBom) { 'already UTF-8 (BOM present)' } else { 'disabled by -SourceEncoding 0' }
            Write-Verbose "  Encoding repair skipped: $reason"
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            $decoded = $false
        } else {
            $enc = [System.Text.Encoding]::GetEncoding($SourceEncoding)
            $text = $enc.GetString($bytes)
            $decoded = $true
            Write-Verbose "  Decoded as codepage $SourceEncoding ($($enc.WebName))"
        }

        # Split on every newline form, INCLUDING NEL/LS/PS, so a capture that already
        # picked up stray U+0085 terminators is normalised the same way.
        $lines = $text -split "`r`n|`r|`n|`u{0085}|`u{2028}|`u{2029}"

        # ---- Stage 2: reflow -------------------------------------------------------
        $out = [System.Collections.Generic.List[string]]::new($lines.Count)
        $reflowed = 0
        $recovered = 0

        foreach ($line in $lines) {
            if ($line.Length -gt $MinLineLength -and $line -match $padPattern) {
                $reflowed++
                foreach ($segment in ($line -split $padPattern)) {
                    $piece = $segment.Trim()
                    if ($piece.Length -eq 0) { continue }
                    if ($piece -match $gitModeLine) { $piece = " $piece" }
                    $out.Add($piece)
                    $recovered++
                }
            } else {
                $out.Add($line.TrimEnd())
            }
        }

        # ---- Stage 3: write --------------------------------------------------------
        $target = "$($out -join "`r`n")`r`n"
        $outEnc = [System.Text.UTF8Encoding]::new(-not $NoBom)

        $action = "Rewrite as UTF-8; reflow $reflowed line(s) into $recovered"
        if (-not $PSCmdlet.ShouldProcess($file, $action)) { continue }

        if (-not $NoBackup) {
            Copy-Item -LiteralPath $file -Destination "$file.bak" -Force
        }
        [System.IO.File]::WriteAllText($file, $target, $outEnc)

        [pscustomobject]@{
            File          = $file
            Decoded       = $decoded
            SourceCodepage= if ($decoded) { $SourceEncoding } else { $null }
            LinesBefore   = $lines.Count
            LinesAfter    = $out.Count
            LinesReflowed = $reflowed
            LinesRecovered= $recovered
            Backup        = if ($NoBackup) { $null } else { "$file.bak" }
        }
    }
}
