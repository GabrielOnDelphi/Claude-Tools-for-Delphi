Add-Type -AssemblyName 'System.IO.Compression'
Add-Type -AssemblyName 'System.IO.Compression.FileSystem'

$docxPath = 'c:\MyBooks\example.docx'

# Restore from backup if it exists (in case previous run corrupted it)
if (Test-Path "$docxPath.bak") {
    Copy-Item "$docxPath.bak" $docxPath -Force
    Write-Output "Restored from backup."
} else {
    Copy-Item $docxPath "$docxPath.bak" -Force
    Write-Output "Backup created."
}

$zip = [System.IO.Compression.ZipFile]::Open($docxPath, [System.IO.Compression.ZipArchiveMode]::Update)
$entry = $zip.GetEntry('word/document.xml')
$stream = $entry.Open()
$reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
$xmlText = $reader.ReadToEnd()
$reader.Close()
$stream.Close()

# In Word XML, text within a cell can be split across multiple <w:t> elements.
# Simple string paths like ~/.claude/CLAUDE.md might be in a single <w:t> or split.
# Let's check which ones are findable as-is.

$replacements = @(
    @('~/.claude/CLAUDE.md', '%USERPROFILE%\.claude\CLAUDE.md'),
    @('./.claude/CLAUDE.md', '.\.claude\CLAUDE.md'),
    @('./.claude/rules/*.md', '.\.claude\rules\*.md'),
    @('./CLAUDE.md', '.\CLAUDE.md'),
    @('./CLAUDE.local.md', '.\CLAUDE.local.md'),
    @('~/.claude/projects/&lt;project&gt; /memory/MEMORY.md', '%USERPROFILE%\.claude\projects\&lt;project&gt;\memory\MEMORY.md'),
    @('~/.claude/projects/&lt;project&gt;/memory/MEMORY.md', '%USERPROFILE%\.claude\projects\&lt;project&gt;\memory\MEMORY.md')
)

$count = 0
foreach ($r in $replacements) {
    $old = $r[0]
    $new = $r[1]
    if ($xmlText.Contains($old)) {
        $xmlText = $xmlText.Replace($old, $new)
        Write-Output "Replaced: $old -> $new"
        $count++
    } else {
        Write-Output "Not found as plain string: $old"
    }
}

# Also search for partial fragments that might indicate split XML runs
# Look for ~/  ./ and similar patterns
$patterns = @('~/', './')
foreach ($p in $patterns) {
    $remaining = ($xmlText | Select-String -Pattern [regex]::Escape($p) -AllMatches).Matches.Count
    Write-Output "Remaining occurrences of '$p': $remaining"
}

# Write back
$entry.Delete()
$newEntry = $zip.CreateEntry('word/document.xml', [System.IO.Compression.CompressionLevel]::Optimal)
$writeStream = $newEntry.Open()
$writer = New-Object System.IO.StreamWriter($writeStream, (New-Object System.Text.UTF8Encoding($false)))
$writer.Write($xmlText)
$writer.Close()
$writeStream.Close()
$zip.Dispose()

Write-Output "`nTotal replacements: $count"
Write-Output "Document updated."
