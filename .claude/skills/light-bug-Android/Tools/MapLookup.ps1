<#
  MapLookup.ps1 — resolve an address inside a Delphi-built binary to Unit.RoutineName + offset,
  using the linker .map file ("Publics by Value" section).

  Why: Delphi Android .so files are stripped (only .dynsym; no .symtab, no .debug_info), so
  ndk-stack and llvm-addr2line resolve nothing on them. The .map is the only symbolication path.
  Works equally for Win32/Win64 maps.

  Usage:
    MapLookup.ps1 -Map App.map -Offset 0x17BB40                          # offset inside the CODE segment
    MapLookup.ps1 -Map App.map -Address 0x6EDB17BB40 -Base 0x6EDB000000  # runtime address - load base
    MapLookup.ps1 -Map App.map -Name TFormMain.FormCreate                # reverse: symbol -> offset

  Calibration on a new target: resolve a KNOWN routine with -Name, feed its offset back with
  -Offset, confirm the same name returns. A constant difference (segment base convention of that
  map) goes in via -Delta.

  Exit codes: 0 = found, 1 = error/no match.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Map,
    [string]$Offset,
    [string]$Address,
    [string]$Base,
    [string]$Name,
    [string]$Delta = '0',
    [string]$Segment = '0001',
    [int]$Neighbors = 2
)

function ConvertTo-U64([string]$Hex) {
    if ([string]::IsNullOrWhiteSpace($Hex)) { throw 'Empty hex value' }
    $clean = $Hex.Trim() -replace '^(0x|\$)', ''
    return [Convert]::ToUInt64($clean, 16)
}

if (-not (Test-Path -LiteralPath $Map)) { Write-Error "Map file not found: $Map"; exit 1 }

$modeCount = 0
if ($Offset)  { $modeCount++ }
if ($Address) { $modeCount++ }
if ($Name)    { $modeCount++ }
if ($modeCount -ne 1) { Write-Error 'Pass exactly ONE of -Offset, -Address (+ -Base), or -Name.'; exit 1 }
if ($Address -and -not $Base) { Write-Error '-Address needs -Base (the .so load base from /proc/<pid>/maps or the logcat DEBUG block).'; exit 1 }

# Parse the 'Publics by Value' section: lines like ' 0001:0000000000002340       Unit1.TForm1.Button1Click'
$inSection = $false
$entries = New-Object 'System.Collections.Generic.List[object]'
$reader = New-Object System.IO.StreamReader($Map)
try {
    while ($null -ne ($line = $reader.ReadLine())) {
        if (-not $inSection) {
            if ($line -match 'Address\s+Publics by Value') { $inSection = $true }
            continue
        }
        if ($line -match '^\s*Line numbers for' -or $line -match '^\s*Bound resource') { break }
        if ($line -match '^\s*([0-9A-Fa-f]{4}):([0-9A-Fa-f]{1,16})\s+(\S.*?)\s*$') {
            if ($Matches[1] -eq $Segment) {
                $entries.Add([pscustomobject]@{ Off = [Convert]::ToUInt64($Matches[2], 16); Sym = $Matches[3] })
            }
        }
    }
}
finally { $reader.Close() }

if ($entries.Count -eq 0) { Write-Error "No 'Publics by Value' entries for segment $Segment in $Map. Is the linker option 'Map file = Detailed' enabled, and is this the right segment?"; exit 1 }

$sorted = @($entries | Sort-Object Off)

if ($Name) {
    $hits = @($sorted | Where-Object { $_.Sym -like "*$Name*" } | Select-Object -First 10)
    if ($hits.Count -eq 0) { Write-Error "No symbol matches *$Name*."; exit 1 }
    foreach ($h in $hits) { '{0}:{1:X8}  {2}' -f $Segment, $h.Off, $h.Sym }
    exit 0
}

[uint64]$target = 0
if ($Address) {
    $a = ConvertTo-U64 $Address
    $b = ConvertTo-U64 $Base
    if ($a -lt $b) { Write-Error 'Address is below Base.'; exit 1 }
    $target = $a - $b
} else {
    $target = ConvertTo-U64 $Offset
}
$d = ConvertTo-U64 $Delta
if ($d -gt $target) { Write-Error 'Delta is larger than the target offset.'; exit 1 }
$target = $target - $d

# Largest entry whose offset <= target (binary search over the sorted array)
$bestIdx = -1
$lo = 0
$hi = $sorted.Count - 1
while ($lo -le $hi) {
    $mid = [int][Math]::Floor(($lo + $hi) / 2)
    if ($sorted[$mid].Off -le $target) { $bestIdx = $mid; $lo = $mid + 1 } else { $hi = $mid - 1 }
}

if ($bestIdx -lt 0) {
    Write-Error ('Offset 0x{0:X} is below the first public (0x{1:X}). Wrong map, wrong base, or missing -Delta calibration.' -f $target, $sorted[0].Off)
    exit 1
}

$best = $sorted[$bestIdx]
''
'Target offset : 0x{0:X}' -f $target
'Symbol        : {0}' -f $best.Sym
'Symbol start  : 0x{0:X}' -f $best.Off
'Offset inside : +0x{0:X} ({1} bytes into the routine)' -f ($target - $best.Off), ($target - $best.Off)
if ($bestIdx -eq $sorted.Count - 1) {
    'NOTE          : this is the LAST public in the map — if the inside-offset looks huge, the address is past known code (wrong map or base).'
}
''
'Neighbors:'
$from = [Math]::Max(0, $bestIdx - $Neighbors)
$to   = [Math]::Min($sorted.Count - 1, $bestIdx + $Neighbors)
for ($i = $from; $i -le $to; $i++) {
    $mark = '  '
    if ($i -eq $bestIdx) { $mark = '->' }
    '{0} {1}:{2:X8}  {3}' -f $mark, $Segment, $sorted[$i].Off, $sorted[$i].Sym
}
exit 0
