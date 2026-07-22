$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open('c:\MyBooks\example.docx')

# Find and replace Linux-style paths with Windows paths in the entire document
$find = $doc.Content.Find

# Replace ~/.claude/ with %USERPROFILE%\.claude\
$replacements = @(
    @('~/.claude/CLAUDE.md', '%USERPROFILE%\.claude\CLAUDE.md'),
    @('./.claude/CLAUDE.md', '.\.claude\CLAUDE.md'),
    @('./.claude/rules/*.md', '.\.claude\rules\*.md'),
    @('./CLAUDE.md', '.\CLAUDE.md'),
    @('./CLAUDE.local.md', '.\CLAUDE.local.md'),
    @('~/.claude/projects/<project> /memory/MEMORY.md', '%USERPROFILE%\.claude\projects\<project>\memory\MEMORY.md')
)

foreach ($r in $replacements) {
    $find = $doc.Content.Find
    $find.ClearFormatting()
    $find.Replacement.ClearFormatting()
    $find.Text = $r[0]
    $find.Replacement.Text = $r[1]
    $find.Forward = $true
    $find.Wrap = 1  # wdFindContinue
    $find.Format = $false
    $find.MatchCase = $true
    $find.MatchWholeWord = $false
    $result = $find.Execute([ref]$false, [ref]$false, [ref]$false, [ref]$false, [ref]$false, [ref]$false, [ref]$true, [ref]1, [ref]$false, [ref]$r[1], [ref]2)
    Write-Output "Replace '$($r[0])' -> '$($r[1])': $result"
}

$doc.Save()
$doc.Close()
$word.Quit()
Write-Output "Done."
