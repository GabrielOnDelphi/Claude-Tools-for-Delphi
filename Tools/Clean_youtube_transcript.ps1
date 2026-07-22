# clean_transcript.ps1
# Cleans up YouTube auto-generated transcripts.
#   - Removes timestamp-only lines (e.g. "0:20", "12:34", "1:34:54")
#   - Merges line-broken sentences back into flowing text
#   - Adds paragraph breaks every ~500 chars at sentence boundaries
#
# Usage:
#   .\clean_transcript.ps1 <input.txt> [output.txt]
# If output path is omitted, writes "<input> (cleaned).txt" next to the input.

param(
    [Parameter(Mandatory = $true, Position = 0)][string]$InputFile,
    [Parameter(Position = 1)][string]$OutputFile
)

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Error "File not found: $InputFile"
    exit 1
}

$resolved = (Resolve-Path -LiteralPath $InputFile).Path

if (-not $OutputFile) {
    $dir  = Split-Path -Parent $resolved
    $name = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
    $ext  = [System.IO.Path]::GetExtension($resolved)
    if (-not $ext) { $ext = '.txt' }
    $OutputFile = Join-Path $dir "$name (cleaned)$ext"
}

# Timestamp-only line: "0:20", "12:34", "1:34:54", etc.
$timestampPattern = '^\s*\d{1,2}:\d{2}(:\d{2})?\s*$'

$lines = Get-Content -LiteralPath $resolved -Encoding UTF8
$kept = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines) {
    if ($line -match $timestampPattern) { continue }
    $trimmed = $line.Trim()
    if ($trimmed -eq '') { continue }
    $kept.Add($trimmed)
}

# Merge into one stream and collapse runs of whitespace.
$text = ($kept -join ' ') -replace '\s+', ' '

# Split into sentences, then regroup into ~500-char paragraphs ending at a sentence boundary.
$sentences = [System.Text.RegularExpressions.Regex]::Split($text, '(?<=[.!?])\s+')
$paragraphs = New-Object System.Collections.Generic.List[string]
$buffer = New-Object System.Text.StringBuilder
foreach ($s in $sentences) {
    if ($buffer.Length -gt 0) { [void]$buffer.Append(' ') }
    [void]$buffer.Append($s)
    if ($buffer.Length -ge 500) {
        $paragraphs.Add($buffer.ToString())
        $buffer.Length = 0
    }
}
if ($buffer.Length -gt 0) { $paragraphs.Add($buffer.ToString()) }

$result = $paragraphs -join "`r`n`r`n"

Set-Content -LiteralPath $OutputFile -Value $result -Encoding UTF8

Write-Host "Cleaned transcript written to:"
Write-Host "  $OutputFile"
Write-Host ""
Write-Host "  Input lines:    $($lines.Count)"
Write-Host "  Kept lines:     $($kept.Count)"
Write-Host "  Paragraphs out: $($paragraphs.Count)"
