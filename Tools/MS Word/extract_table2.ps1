# Extract tables from docx XML directly (no Word COM needed)
Add-Type -AssemblyName System.IO.Compression.FileSystem

$docxPath = 'c:\MyBooks\example.docx'
$zip = [System.IO.Compression.ZipFile]::OpenRead($docxPath)
$entry = $zip.GetEntry('word/document.xml')
$stream = $entry.Open()
$reader = New-Object System.IO.StreamReader($stream)
$xml = [xml]$reader.ReadToEnd()
$reader.Close()
$stream.Close()
$zip.Dispose()

$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')

$tables = $xml.SelectNodes('//w:tbl', $ns)
Write-Output "Total tables in document: $($tables.Count)"

$tableNum = 0
foreach ($table in $tables) {
    $tableNum++
    $rows = $table.SelectNodes('w:tr', $ns)

    # Check if any cell contains path-like content (~/. or /home or linux paths)
    $tableText = $table.InnerText
    if ($tableText -match '~/\.' -or $tableText -match '/home' -or $tableText -match 'CLAUDE\.md' -or $tableText -match '\.claude') {
        Write-Output "`n=== TABLE $tableNum (rows: $($rows.Count)) ==="
        $rowNum = 0
        foreach ($row in $rows) {
            $rowNum++
            $cells = $row.SelectNodes('w:tc', $ns)
            $cellTexts = @()
            foreach ($cell in $cells) {
                $paras = $cell.SelectNodes('.//w:t', $ns)
                $cellContent = ($paras | ForEach-Object { $_.InnerText }) -join ''
                $cellTexts += $cellContent
            }
            Write-Output "Row ${rowNum}: $($cellTexts -join ' | ')"
        }
    }
}
