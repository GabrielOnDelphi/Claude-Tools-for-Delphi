$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open('c:\MyBooks\example.docx')

$range = $doc.GoTo(1, 1, 97)
$startPos = $range.Start
$endRange = $doc.GoTo(1, 1, 100)
$endPos = $endRange.Start
$pageRange = $doc.Range($startPos, $endPos)

Write-Output ("Tables in range: " + $pageRange.Tables.Count)

if ($pageRange.Tables.Count -gt 0) {
    $table = $pageRange.Tables[1]
    Write-Output ("Rows: " + $table.Rows.Count)
    for ($r = 1; $r -le $table.Rows.Count; $r++) {
        $rowText = ""
        for ($c = 1; $c -le $table.Columns.Count; $c++) {
            try {
                $cell = $table.Cell($r, $c).Range.Text
                $cell = $cell.Replace("`r", "").Replace("`n", "").Replace("`a", "")
                $cell = $cell -replace '[\x00-\x1F]', ''
                $rowText += $cell + " || "
            } catch { $rowText += "[merged] || " }
        }
        Write-Output "Row ${r}: $rowText"
    }
}

$doc.Close($false)
$word.Quit()
