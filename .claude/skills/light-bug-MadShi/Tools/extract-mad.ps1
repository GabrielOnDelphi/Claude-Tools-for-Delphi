# Extract a madExcept .mad attachment from one or more Thunderbird mbox files.
# Works for any product whose crash reports arrive as .mad e-mail attachments.
#
# -MboxPath accepts MULTIPLE mbox files. Candidates from all of them are merged
# newest-first and de-duplicated by From+Subject+Date (the same report often sits
# in both a parent folder and a version subfolder).
#
# Three modes:
#   (default)        Write the newest intact .mad to OutDir. Prints its path on stdout (last line).
#   -List [-Top N]   Print one tab-separated line per candidate to stdout:
#                    index<TAB>date<TAB>from<TAB>subject<TAB>size<TAB>exeVersion<TAB>status<TAB>source
#                    Newest-first, de-duplicated. Index is 1-based. Default Top=10.
#   -Index N         Extract candidate #N (1=newest in the merged list) and write it.
#
# All progress messages go to stderr so callers can capture stdout cleanly.

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string[]] $MboxPath,
  [string] $OutDir    = 'c:\AI\Claude Code\Temp',
  [string] $OutPrefix = 'bug-',
  [switch] $List,
  [int]    $Top   = 10,
  [int]    $Index = 0
)

$ErrorActionPreference = 'Stop'

function Log($msg) { [Console]::Error.WriteLine($msg) }

# RFC 5322 header unfolding: continuation lines start with whitespace.
function Unfold-Headers([string] $headers) {
  return [regex]::Replace($headers, "(\r?\n)([ \t]+)", ' ')
}

# Peek the madExcept "version : X" line in the first ~2 KB of the decoded payload.
function ParseMadExeVersion([byte[]] $bytes) {
  if (-not $bytes -or $bytes.Length -eq 0) { return '' }
  $peekLen = [Math]::Min(2048, $bytes.Length)
  try   { $head = [System.Text.Encoding]::UTF8.GetString($bytes, 0, $peekLen) }
  catch { $head = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $peekLen) }
  if ($head -match '(?im)^version\s*:\s*(\S+)') { return $matches[1].Trim() }
  return ''
}

# Parse an RFC 5322 Date header to a sortable UTC value. Strips trailing "(...)"
# timezone comments. Unparseable dates sort last (MinValue).
function ParseSortKey([string] $date) {
  $clean = ($date -replace '\(.*?\)', '').Trim()
  # Strip a leading day-of-week ("Mon, ") so a wrong/mismatched weekday can't fail the parse.
  $clean = $clean -replace '^[A-Za-z]{3,9},\s*', ''
  $dto = [DateTimeOffset]::MinValue
  if ([DateTimeOffset]::TryParse($clean, [ref] $dto)) { return $dto.UtcDateTime }
  return [DateTime]::MinValue
}

# Walk one message, return $null or a hashtable describing its .mad attachment.
function ProcessMessage([string] $text, [int] $msgStart, [int] $msgEnd) {
  $msg = $text.Substring($msgStart, $msgEnd - $msgStart)

  $hdrEnd = $msg.IndexOf("`r`n`r`n"); $sep = "`r`n`r`n"
  if ($hdrEnd -lt 0) { $hdrEnd = $msg.IndexOf("`n`n"); $sep = "`n`n" }
  if ($hdrEnd -lt 0) { return $null }
  $rawHeaders = $msg.Substring(0, $hdrEnd)
  $body       = $msg.Substring($hdrEnd + $sep.Length)
  $headers    = Unfold-Headers $rawHeaders

  $subject = if ($headers -match '(?im)^Subject:\s*(.+?)\s*$') { $matches[1].Trim() } else { '(no subject)' }
  $date    = if ($headers -match '(?im)^Date:\s*(.+?)\s*$')    { $matches[1].Trim() } else { '(no date)' }
  $from    = if ($headers -match '(?im)^From:\s*(.+?)\s*$')    { $matches[1].Trim() } else { '(unknown)' }

  if (-not ($headers -match '(?im)Content-Type:\s*multipart/[^\r\n]*?\bboundary\s*=\s*("([^"]+)"|([^\s;]+))')) {
    return $null
  }
  $boundary = if ($matches[2]) { $matches[2] } else { $matches[3] }

  $parts = [regex]::Split($body, [regex]::Escape("--$boundary"))

  foreach ($rawPart in $parts) {
    $part = $rawPart.TrimStart("`r","`n")
    if ($part -eq '' -or $part.StartsWith('--')) { continue }

    $pHdrEnd = $part.IndexOf("`r`n`r`n"); $pSep = "`r`n`r`n"
    if ($pHdrEnd -lt 0) { $pHdrEnd = $part.IndexOf("`n`n"); $pSep = "`n`n" }
    if ($pHdrEnd -lt 0) { continue }
    $pHdr  = Unfold-Headers $part.Substring(0, $pHdrEnd)
    $pBody = $part.Substring($pHdrEnd + $pSep.Length)

    $fname = $null
    if ($pHdr -match '(?im)Content-Disposition:[^\r\n]*?\bfilename\s*=\s*("([^"]+)"|([^\s;]+))') {
      $fname = if ($matches[2]) { $matches[2] } else { $matches[3] }
    } elseif ($pHdr -match '(?im)Content-Type:[^\r\n]*?\bname\s*=\s*("([^"]+)"|([^\s;]+))') {
      $fname = if ($matches[2]) { $matches[2] } else { $matches[3] }
    }
    if (-not $fname)               { continue }
    if ($fname -notmatch '\.mad$') { continue }

    $isStub = $pBody -match 'You deleted an attachment from this message'
    return @{
      Date     = $date
      From     = $from
      Subject  = $subject
      Filename = $fname
      Base64   = $pBody
      IsStub   = $isStub
      SortKey  = (ParseSortKey $date)
    }
  }
  return $null
}

# Read one mbox file and return every .mad-bearing candidate in it.
function Get-Candidates([string] $path) {
  $result = New-Object 'System.Collections.Generic.List[object]'
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $text  = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)
  $leaf  = [System.IO.Path]::GetFileName($path)

  $starts = New-Object 'System.Collections.Generic.List[int]'
  if ($text.StartsWith('From ')) { $starts.Add(0) }
  $idx = 0
  while ($true) {
    $next = $text.IndexOf("`nFrom ", $idx + 1)
    if ($next -lt 0) { break }
    $starts.Add($next + 1)
    $idx = $next + 1
  }
  if ($starts.Count -eq 0) { return $result }

  for ($i = $starts.Count - 1; $i -ge 0; $i--) {
    $msgStart = $starts[$i]
    $msgEnd   = if ($i -lt $starts.Count - 1) { $starts[$i+1] } else { $text.Length }
    $cand = ProcessMessage $text $msgStart $msgEnd
    if ($cand -ne $null) {
      $cand.SourceMbox = $leaf
      $result.Add($cand) | Out-Null
    }
  }
  return $result
}

# Decode a candidate's base64 body, or $null if it is a stub / invalid / too small.
function DecodeCandidate($cand) {
  if ($cand.IsStub) { return $null }
  $clean = ($cand.Base64 -replace '\r','' -replace '\n','').Trim()
  try   { $rawBytes = [Convert]::FromBase64String($clean) }
  catch { return $null }
  if ($rawBytes.Length -lt 1024) { return $null }
  return $rawBytes
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# Gather candidates across all mboxes.
$all = New-Object 'System.Collections.Generic.List[object]'
foreach ($mb in $MboxPath) {
  if (-not (Test-Path $mb)) { Log "WARN: mbox not found, skipping: $mb"; continue }
  Log "Reading mbox: $mb"
  $cands = Get-Candidates $mb
  Log ("  found {0} .mad candidate(s)" -f $cands.Count)
  foreach ($c in $cands) { $all.Add($c) | Out-Null }
}
if ($all.Count -eq 0) { throw 'No messages with a .mad attachment found in any mbox.' }

# Merge newest-first, then de-duplicate by visible identity (From + Subject + Date).
# Scriptblock sort key: Sort-Object -Property reads PSObject members, which do NOT
# expose a hashtable's keys; { $_.SortKey } routes through the hashtable accessor.
# Seq is the gather order (already newest-first per mbox); used as a tiebreaker because
# Windows PowerShell 5.1's Sort-Object is unstable and would otherwise scramble equal keys.
for ($s = 0; $s -lt $all.Count; $s++) { $all[$s].Seq = $s }
$sorted = $all | Sort-Object -Property `
  @{ Expression = { $_.SortKey }; Descending = $true }, `
  @{ Expression = { $_.Seq };     Descending = $false }
$seen   = @{}
$candidates = New-Object 'System.Collections.Generic.List[object]'
foreach ($c in $sorted) {
  $key = "{0}|{1}|{2}" -f $c.From, $c.Subject, $c.Date
  if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $candidates.Add($c) | Out-Null }
}
Log ("{0} unique .mad candidate(s) after merge/de-dup" -f $candidates.Count)

# --- LIST MODE ------------------------------------------------------------

if ($List) {
  $shown = 0
  for ($k = 0; $k -lt $candidates.Count -and $shown -lt $Top; $k++) {
    $c = $candidates[$k]
    $sizeBytes = 0
    $exeVer    = ''
    if (-not $c.IsStub) {
      $raw = DecodeCandidate $c
      if ($raw -ne $null) { $sizeBytes = $raw.Length; $exeVer = ParseMadExeVersion $raw }
    }
    $status = if ($c.IsStub) { 'stub' } elseif ($sizeBytes -eq 0) { 'invalid' } else { 'ok' }
    $idx = $shown + 1
    $cleanSubj = ($c.Subject -replace "`t",' ')
    $cleanFrom = ($c.From    -replace "`t",' ')
    $cleanDate = ($c.Date    -replace "`t",' ')
    Write-Output ("{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}" -f $idx, $cleanDate, $cleanFrom, $cleanSubj, $sizeBytes, $exeVer, $status, $c.SourceMbox)
    $shown++
  }
  exit 0
}

# --- INDEX or DEFAULT (newest) MODE --------------------------------------

if ($Index -gt 0) {
  if ($Index -gt $candidates.Count) { throw "Index $Index out of range (only $($candidates.Count) candidates)." }
  $picked = $candidates[$Index - 1]
  Log ("Picked index {0}: {1} | {2} | {3}" -f $Index, $picked.Date, $picked.Subject, $picked.SourceMbox)
  $rawBytes = DecodeCandidate $picked
  if ($rawBytes -eq $null) {
    if ($picked.IsStub) { throw "Index $Index is a stub (attachment was manually deleted)." }
    throw "Index $Index has an invalid or undersized payload."
  }
} else {
  $rawBytes = $null
  $picked   = $null
  foreach ($c in $candidates) {
    Log ("  candidate: {0} | {1} | {2}" -f $c.Date, $c.Subject, $c.SourceMbox)
    $tryBytes = DecodeCandidate $c
    if ($tryBytes -ne $null) { $rawBytes = $tryBytes; $picked = $c; break }
    if ($c.IsStub) { Log '  -> stub; trying older.' } else { Log '  -> invalid/too small; trying older.' }
  }
  if ($rawBytes -eq $null) { throw 'No intact .mad attachment found in any mbox.' }
}

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$outName = "$OutPrefix$stamp-$([System.IO.Path]::GetFileName($picked.Filename))"
$outPath = Join-Path $OutDir $outName
[System.IO.File]::WriteAllBytes($outPath, $rawBytes)
Log ("Wrote {0} bytes to {1}" -f $rawBytes.Length, $outPath)

Write-Output $outPath
exit 0
