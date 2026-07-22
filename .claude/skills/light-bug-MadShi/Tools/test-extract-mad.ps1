# Synthetic-mbox tests for extract-mad.ps1 (the /light-bug-MadShi pipeline extractor).
# Builds fake mbox files in c:\AI\Claude Code\Temp\extractor-tests\, runs the
# extractor against each, and asserts the right .mad comes out.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File test-extract-mad.ps1
# Exit code 0 = all pass, 1 = at least one failure.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Extractor = 'c:\Users\trei\.claude\skills\light-bug-MadShi\Tools\extract-mad.ps1'
$TestRoot  = 'c:\AI\Claude Code\Temp\extractor-tests'
$OutDir    = Join-Path $TestRoot 'out'

if (Test-Path $TestRoot) { Remove-Item -Recurse -Force $TestRoot }
New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir   | Out-Null

if (-not (Test-Path $Extractor)) { throw "Extractor not found: $Extractor" }

$results = New-Object 'System.Collections.Generic.List[object]'

# --- helpers --------------------------------------------------------------

function New-Payload([int] $sizeBytes, [byte] $seed) {
  # Deterministic byte sequence so tests can assert exact equality.
  $b = New-Object 'byte[]' $sizeBytes
  for ($i = 0; $i -lt $sizeBytes; $i++) { $b[$i] = ($seed + $i) -band 0xFF }
  return ,$b
}

# Build a synthetic .mad payload that starts with a madExcept-style header
# (so the extractor's ParseMadExeVersion can pick up the version), padded to
# the requested size with deterministic bytes.
function New-MadPayload([int] $sizeBytes, [byte] $seed, [string] $version) {
  $headerText = @"
exception class   : EAccessViolation
exception message : Test crash
executable        : BionixWallpaper.exe
version           : $version
exec. date/time   : 2026-05-05 12:00
"@
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)
  if ($sizeBytes -le $headerBytes.Length) { return ,$headerBytes }
  $b = New-Object 'byte[]' $sizeBytes
  [Array]::Copy($headerBytes, 0, $b, 0, $headerBytes.Length)
  for ($i = $headerBytes.Length; $i -lt $sizeBytes; $i++) {
    $b[$i] = ($seed + $i) -band 0xFF
  }
  return ,$b
}

function ToBase64Wrapped([byte[]] $bytes, [int] $width = 76) {
  $s = [Convert]::ToBase64String($bytes)
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $s.Length; $i += $width) {
    $len = [Math]::Min($width, $s.Length - $i)
    [void]$sb.AppendLine($s.Substring($i, $len))
  }
  return $sb.ToString().TrimEnd("`r","`n")
}

function New-MadMessage {
  param(
    [string] $FromDate,                  # mbox "From " line date
    [string] $Subject,
    [string] $Date,                      # email Date: header
    [string] $Boundary,
    [byte[]] $MadBytes,                  # NIL/empty = stub
    [switch] $StubAttachment,
    [string] $FilenameParam = 'BioniX bug report.mad',
    [switch] $UnquotedBoundary,
    [switch] $FoldedContentType,
    [switch] $FoldedDisposition,
    [string] $LineEnd = "`r`n"
  )

  $boundaryHeader = if ($UnquotedBoundary) {
    "Content-Type: multipart/mixed; boundary=$Boundary"
  } elseif ($FoldedContentType) {
    "Content-Type: multipart/mixed;${LineEnd} boundary=`"$Boundary`""
  } else {
    "Content-Type: multipart/mixed; boundary=`"$Boundary`""
  }

  $disposition = if ($FoldedDisposition) {
    "Content-Disposition: attachment;${LineEnd} filename=`"$FilenameParam`""
  } else {
    "Content-Disposition: attachment; filename=`"$FilenameParam`""
  }

  $body = if ($StubAttachment) {
    'You deleted an attachment from this message. The original was saved separately.'
  } elseif ($MadBytes -and $MadBytes.Length -gt 0) {
    ToBase64Wrapped $MadBytes
  } else {
    ''
  }

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("From - $FromDate$LineEnd")
  [void]$sb.Append("From: bionix-bug@example.com$LineEnd")
  [void]$sb.Append("To: support@example.com$LineEnd")
  [void]$sb.Append("Subject: $Subject$LineEnd")
  [void]$sb.Append("Date: $Date$LineEnd")
  [void]$sb.Append("MIME-Version: 1.0$LineEnd")
  [void]$sb.Append("$boundaryHeader$LineEnd")
  [void]$sb.Append($LineEnd)
  [void]$sb.Append("This is a multi-part message in MIME format.$LineEnd")
  [void]$sb.Append("--$Boundary$LineEnd")
  [void]$sb.Append("Content-Type: text/plain; charset=utf-8$LineEnd")
  [void]$sb.Append("Content-Transfer-Encoding: 7bit$LineEnd")
  [void]$sb.Append($LineEnd)
  [void]$sb.Append("BioniX crashed.$LineEnd")
  [void]$sb.Append($LineEnd)
  [void]$sb.Append("--$Boundary$LineEnd")
  if ($StubAttachment) {
    [void]$sb.Append("Content-Type: text/plain; charset=utf-8$LineEnd")
    [void]$sb.Append("Content-Transfer-Encoding: 7bit$LineEnd")
  } else {
    [void]$sb.Append("Content-Type: application/octet-stream;${LineEnd} name=`"$FilenameParam`"$LineEnd")
    [void]$sb.Append("Content-Transfer-Encoding: base64$LineEnd")
  }
  [void]$sb.Append("$disposition$LineEnd")
  [void]$sb.Append($LineEnd)
  [void]$sb.Append("$body$LineEnd")
  [void]$sb.Append($LineEnd)
  [void]$sb.Append("--$Boundary--$LineEnd")
  return $sb.ToString()
}

function Write-Mbox([string] $Path, [string[]] $Messages) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($m in $Messages) {
    [void]$sb.Append($m)
    if (-not $m.EndsWith("`n")) { [void]$sb.Append("`r`n") }
    [void]$sb.Append("`r`n")
  }
  # Write as Windows-1252 so byte values round-trip cleanly through the
  # extractor (which reads via codepage 1252).
  $enc = [System.Text.Encoding]::GetEncoding(1252)
  [System.IO.File]::WriteAllBytes($Path, $enc.GetBytes($sb.ToString()))
}

function Run-Extractor([string] $MboxPath, [string[]] $ExtraArgs = @()) {
  # Capture stdout (last line = path) and stderr separately so we can assert.
  # Start-Process -ArgumentList re-tokenizes args on spaces, which breaks paths
  # with spaces (e.g. "c:\AI\Claude Code\..."). Quote each value-arg explicitly.
  $tmpOut = [System.IO.Path]::GetTempFileName()
  $tmpErr = [System.IO.Path]::GetTempFileName()
  try {
    $args = @(
      '-NoProfile',
      '-File',     ('"{0}"' -f $Extractor),
      '-MboxPath', ('"{0}"' -f $MboxPath),
      '-OutDir',   ('"{0}"' -f $OutDir)
    )
    if ($ExtraArgs -and $ExtraArgs.Count -gt 0) { $args += $ExtraArgs }
    $proc = Start-Process -FilePath 'powershell.exe' `
      -ArgumentList $args `
      -NoNewWindow -Wait -PassThru `
      -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
    $stdout = [System.IO.File]::ReadAllText($tmpOut)
    $stderr = [System.IO.File]::ReadAllText($tmpErr)
    return [pscustomobject]@{
      ExitCode = $proc.ExitCode
      StdOut   = $stdout
      StdErr   = $stderr
      LastLine = ($stdout -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1)
    }
  } finally {
    Remove-Item -Force $tmpOut, $tmpErr -ErrorAction SilentlyContinue
  }
}

function Assert-Test {
  param(
    [string] $Name,
    [scriptblock] $Body
  )
  Write-Host -NoNewline "  [$Name] "
  try {
    & $Body
    Write-Host 'PASS' -ForegroundColor Green
    $results.Add([pscustomobject]@{ Name=$Name; Pass=$true; Error=$null }) | Out-Null
  } catch {
    Write-Host 'FAIL' -ForegroundColor Red
    Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    $results.Add([pscustomobject]@{ Name=$Name; Pass=$false; Error=$_.Exception.Message }) | Out-Null
  }
}

function Assert-True([bool] $cond, [string] $msg) {
  if (-not $cond) { throw $msg }
}

function Assert-BytesEqual([byte[]] $a, [byte[]] $b, [string] $msg) {
  if ($a.Length -ne $b.Length) { throw "$msg (lengths differ: $($a.Length) vs $($b.Length))" }
  for ($i = 0; $i -lt $a.Length; $i++) {
    if ($a[$i] -ne $b[$i]) { throw "$msg (byte $i differs: $($a[$i]) vs $($b[$i]))" }
  }
}

# --- tests ----------------------------------------------------------------

Write-Host 'extract-mad.ps1— synthetic mbox tests' -ForegroundColor Cyan
Write-Host ''

# Test 1: single intact message — basic happy path
Assert-Test 'single intact message' {
  $payload = New-Payload 4096 0x42
  $msg = New-MadMessage -FromDate 'Mon May 05 10:00:00 2026' -Subject 'BioniX bug 1' -Date 'Mon, 05 May 2026 10:00:00 +0000' -Boundary 'boundary001' -MadBytes $payload
  $mbox = Join-Path $TestRoot 't1.mbox'
  Write-Mbox $mbox @($msg)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  Assert-True (Test-Path $r.LastLine) "output file missing: $($r.LastLine)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payload 'payload mismatch'
}

# Test 2: newest-first selection — three messages, last has the .mad
Assert-Test 'newest-first selection (3 messages)' {
  $payloadOld    = New-Payload 4096 0x10
  $payloadMiddle = New-Payload 4096 0x20
  $payloadNewest = New-Payload 4096 0x30
  $m1 = New-MadMessage -FromDate 'Mon May 03 09:00:00 2026' -Subject 'old'    -Date 'Mon, 03 May 2026 09:00:00 +0000' -Boundary 'b001' -MadBytes $payloadOld
  $m2 = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 'middle' -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'b002' -MadBytes $payloadMiddle
  $m3 = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 'newest' -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'b003' -MadBytes $payloadNewest
  $mbox = Join-Path $TestRoot 't2.mbox'
  Write-Mbox $mbox @($m1, $m2, $m3)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payloadNewest 'should pick the NEWEST message'
}

# Test 3: stub (manually deleted) on newest, intact on previous
Assert-Test 'skip stub, fall back to previous intact message' {
  $payloadOld = New-Payload 4096 0x55
  $stub      = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 'stub'   -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'b101' -StubAttachment
  $intact    = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 'intact' -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'b102' -MadBytes $payloadOld
  $mbox = Join-Path $TestRoot 't3.mbox'
  # Order in file: intact first (older), stub last (newest)
  Write-Mbox $mbox @($intact, $stub)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payloadOld 'should fall back to intact message'
}

# Test 4: folded Content-Type header (multipart and boundary on different lines)
Assert-Test 'folded Content-Type header' {
  $payload = New-Payload 4096 0x77
  $msg = New-MadMessage -FromDate 'Mon May 05 10:00:00 2026' -Subject 'folded ct' -Date 'Mon, 05 May 2026 10:00:00 +0000' -Boundary 'foldedb01' -MadBytes $payload -FoldedContentType
  $mbox = Join-Path $TestRoot 't4.mbox'
  Write-Mbox $mbox @($msg)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payload 'payload mismatch with folded header'
}

# Test 5: folded Content-Disposition (filename on continuation line)
Assert-Test 'folded Content-Disposition (filename on continuation line)' {
  $payload = New-Payload 4096 0x88
  $msg = New-MadMessage -FromDate 'Mon May 05 10:00:00 2026' -Subject 'folded cd' -Date 'Mon, 05 May 2026 10:00:00 +0000' -Boundary 'b201' -MadBytes $payload -FoldedDisposition
  $mbox = Join-Path $TestRoot 't5.mbox'
  Write-Mbox $mbox @($msg)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payload 'payload mismatch with folded disposition'
}

# Test 6: unquoted boundary value
Assert-Test 'unquoted boundary value' {
  $payload = New-Payload 4096 0x99
  $msg = New-MadMessage -FromDate 'Mon May 05 10:00:00 2026' -Subject 'unq bnd' -Date 'Mon, 05 May 2026 10:00:00 +0000' -Boundary 'NextPart_000_001A_01D75E27' -MadBytes $payload -UnquotedBoundary
  $mbox = Join-Path $TestRoot 't6.mbox'
  Write-Mbox $mbox @($msg)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payload 'payload mismatch with unquoted boundary'
}

# Test 7: tiny payload below 1024-byte stub threshold should be rejected
Assert-Test 'reject below-threshold payload (treated as stub)' {
  $tiny = New-Payload 256 0xAA
  $msg = New-MadMessage -FromDate 'Mon May 05 10:00:00 2026' -Subject 'tiny' -Date 'Mon, 05 May 2026 10:00:00 +0000' -Boundary 'b301' -MadBytes $tiny
  $mbox = Join-Path $TestRoot 't7.mbox'
  Write-Mbox $mbox @($msg)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -ne 0) 'expected non-zero exit when only sub-1KB payloads exist'
}

# Test 8: skip non-.mad attachment, find .mad in older message
Assert-Test 'skip non-.mad attachment' {
  $payloadMad = New-Payload 4096 0xBB
  $payloadJpg = New-Payload 4096 0xCC

  $newest  = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 'jpg'  -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'b401' -MadBytes $payloadJpg -FilenameParam 'screenshot.jpg'
  $older   = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 'mad'  -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'b402' -MadBytes $payloadMad -FilenameParam 'BioniX bug report.mad'
  $mbox = Join-Path $TestRoot 't8.mbox'
  Write-Mbox $mbox @($older, $newest)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payloadMad 'should ignore .jpg and pick .mad from older message'
}

# Test 9: empty mbox should fail cleanly
Assert-Test 'empty mbox fails cleanly' {
  $mbox = Join-Path $TestRoot 't9.mbox'
  [System.IO.File]::WriteAllBytes($mbox, [byte[]]@())

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -ne 0) 'expected non-zero exit on empty mbox'
}

# Test 10: realistic-size .mad (matches actual madExcept output)
Assert-Test 'realistic 80KB payload' {
  $big = New-Payload 81920 0xDD
  $msg = New-MadMessage -FromDate 'Mon May 05 10:00:00 2026' -Subject 'big' -Date 'Mon, 05 May 2026 10:00:00 +0000' -Boundary 'b501' -MadBytes $big
  $mbox = Join-Path $TestRoot 't10.mbox'
  Write-Mbox $mbox @($msg)

  $r = Run-Extractor $mbox
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $big 'realistic-size payload mismatch'
}

# Test 11: -List mode prints one line per candidate (newest-first)
Assert-Test 'list mode: 3 candidates, newest-first, tab-separated' {
  $payloadOld    = New-MadPayload 4096 0x10 '15.20'
  $payloadMiddle = New-MadPayload 4096 0x20 '15.25'
  $payloadNewest = New-MadPayload 4096 0x30 '15.30'
  $m1 = New-MadMessage -FromDate 'Mon May 03 09:00:00 2026' -Subject 'old'    -Date 'Mon, 03 May 2026 09:00:00 +0000' -Boundary 'L01' -MadBytes $payloadOld
  $m2 = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 'middle' -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'L02' -MadBytes $payloadMiddle
  $m3 = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 'newest' -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'L03' -MadBytes $payloadNewest
  $mbox = Join-Path $TestRoot 't11.mbox'
  Write-Mbox $mbox @($m1, $m2, $m3)

  $r = Run-Extractor $mbox @('-List')
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  $lines = $r.StdOut -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
  Assert-True ($lines.Count -eq 3) "expected 3 lines, got $($lines.Count): $($r.StdOut)"

  # Newest first: line 1 should reference 'newest', line 3 should reference 'old'
  Assert-True ($lines[0] -match 'newest') "line 1 should be newest: $($lines[0])"
  Assert-True ($lines[2] -match 'old')    "line 3 should be oldest: $($lines[2])"

  # Each line: index<TAB>date<TAB>from<TAB>subject<TAB>size<TAB>exeVer<TAB>status<TAB>source
  $cols = $lines[0] -split "`t"
  Assert-True ($cols.Count -eq 8) "expected 8 tab-separated columns, got $($cols.Count): $($lines[0])"
  Assert-True ($cols[0] -eq '1')       "column 1 should be index '1', got '$($cols[0])'"
  Assert-True ($cols[3] -eq 'newest')  "column 4 should be subject 'newest', got '$($cols[3])'"
  Assert-True ($cols[4] -eq '4096')    "column 5 should be size '4096', got '$($cols[4])'"
  Assert-True ($cols[5] -eq '15.30')   "column 6 should be exe version '15.30', got '$($cols[5])'"
  Assert-True ($cols[6] -eq 'ok')      "column 7 should be status 'ok', got '$($cols[6])'"
  Assert-True ($cols[7] -eq 't11.mbox') "column 8 should be source mbox 't11.mbox', got '$($cols[7])'"
}

# Test 12: -List honors -Top
Assert-Test 'list mode: -Top 2 caps output' {
  $p1 = New-MadPayload 4096 0x10 '15.20'
  $p2 = New-MadPayload 4096 0x20 '15.25'
  $p3 = New-MadPayload 4096 0x30 '15.30'
  $m1 = New-MadMessage -FromDate 'Mon May 03 09:00:00 2026' -Subject 's1' -Date 'Mon, 03 May 2026 09:00:00 +0000' -Boundary 'T01' -MadBytes $p1
  $m2 = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 's2' -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'T02' -MadBytes $p2
  $m3 = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 's3' -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'T03' -MadBytes $p3
  $mbox = Join-Path $TestRoot 't12.mbox'
  Write-Mbox $mbox @($m1, $m2, $m3)

  $r = Run-Extractor $mbox @('-List','-Top','2')
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode)"
  $lines = $r.StdOut -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
  Assert-True ($lines.Count -eq 2) "expected 2 lines (capped), got $($lines.Count)"
}

# Test 13: -List shows stub status correctly
Assert-Test 'list mode: stub message marked as stub' {
  $payload = New-MadPayload 4096 0x55 '15.30'
  $stub    = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 'stubbed' -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'S01' -StubAttachment
  $intact  = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 'intact'  -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'S02' -MadBytes $payload
  $mbox = Join-Path $TestRoot 't13.mbox'
  Write-Mbox $mbox @($intact, $stub)

  $r = Run-Extractor $mbox @('-List')
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode)"
  $lines = $r.StdOut -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
  Assert-True ($lines.Count -eq 2) "expected 2 lines, got $($lines.Count)"
  $cols0 = $lines[0] -split "`t"
  $cols1 = $lines[1] -split "`t"
  Assert-True ($cols0[3] -eq 'stubbed') "first line should be stubbed (newest)"
  Assert-True ($cols0[6] -eq 'stub')    "stubbed status column should be 'stub'"
  Assert-True ($cols1[3] -eq 'intact')  "second line should be intact"
  Assert-True ($cols1[6] -eq 'ok')      "intact status column should be 'ok'"
}

# Test 14: -Index 2 picks the second-newest
Assert-Test 'index mode: -Index 2 picks second-newest' {
  $payloadOld    = New-MadPayload 4096 0x10 '15.20'
  $payloadMiddle = New-MadPayload 4096 0x20 '15.25'
  $payloadNewest = New-MadPayload 4096 0x30 '15.30'
  $m1 = New-MadMessage -FromDate 'Mon May 03 09:00:00 2026' -Subject 'old'    -Date 'Mon, 03 May 2026 09:00:00 +0000' -Boundary 'I01' -MadBytes $payloadOld
  $m2 = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 'middle' -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'I02' -MadBytes $payloadMiddle
  $m3 = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 'newest' -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'I03' -MadBytes $payloadNewest
  $mbox = Join-Path $TestRoot 't14.mbox'
  Write-Mbox $mbox @($m1, $m2, $m3)

  $r = Run-Extractor $mbox @('-Index','2')
  Assert-True ($r.ExitCode -eq 0) "exit code $($r.ExitCode), stderr: $($r.StdErr)"
  $got = [System.IO.File]::ReadAllBytes($r.LastLine)
  Assert-BytesEqual $got $payloadMiddle 'index 2 should produce middle payload'
}

# Test 15: -Index out of range fails
Assert-Test 'index mode: out-of-range index fails' {
  $payload = New-MadPayload 4096 0x77 '15.30'
  $msg = New-MadMessage -FromDate 'Mon May 05 10:00:00 2026' -Subject 'only one' -Date 'Mon, 05 May 2026 10:00:00 +0000' -Boundary 'I999' -MadBytes $payload
  $mbox = Join-Path $TestRoot 't15.mbox'
  Write-Mbox $mbox @($msg)

  $r = Run-Extractor $mbox @('-Index','5')
  Assert-True ($r.ExitCode -ne 0) 'expected non-zero exit when index is out of range'
}

# Test 16: -Index 1 on stub fails (matches the listing where #1 is 'stub')
Assert-Test 'index mode: picking a stub fails clearly' {
  $payload = New-MadPayload 4096 0x88 '15.30'
  $stub   = New-MadMessage -FromDate 'Wed May 05 09:00:00 2026' -Subject 'stubbed' -Date 'Wed, 05 May 2026 09:00:00 +0000' -Boundary 'X01' -StubAttachment
  $intact = New-MadMessage -FromDate 'Tue May 04 09:00:00 2026' -Subject 'intact'  -Date 'Tue, 04 May 2026 09:00:00 +0000' -Boundary 'X02' -MadBytes $payload
  $mbox = Join-Path $TestRoot 't16.mbox'
  Write-Mbox $mbox @($intact, $stub)

  # Index 1 = newest = stub. Should fail with a stub error.
  $r = Run-Extractor $mbox @('-Index','1')
  Assert-True ($r.ExitCode -ne 0) 'expected non-zero exit when picking a stub'
}

# --- summary --------------------------------------------------------------

Write-Host ''
$pass = ($results | Where-Object { $_.Pass }).Count
$fail = ($results | Where-Object { -not $_.Pass }).Count
Write-Host "Results: $pass passed, $fail failed (total $($results.Count))" -ForegroundColor Cyan

if ($fail -gt 0) {
  Write-Host ''
  Write-Host 'Failed tests:' -ForegroundColor Red
  $results | Where-Object { -not $_.Pass } | ForEach-Object {
    Write-Host "  - $($_.Name): $($_.Error)" -ForegroundColor Red
  }
  exit 1
}

exit 0
