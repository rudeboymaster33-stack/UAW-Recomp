$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $root 'project\out\build\win-amd64-relwithdebinfo'
$out = Join-Path $root 'logs\06_crash.txt'
$e = Get-WinEvent -FilterHashtable @{LogName='Application';Id=1000} -MaxEvents 5 | Where-Object { $_.Message -match 'uaw.exe' } | Select-Object -First 1
if (-not $e) { 'No crash event found' | Out-File $out; exit }
$e.TimeCreated.ToString('s') | Out-File $out
$e.Message | Out-File $out -Append
$mod = $e.Properties[3].Value
$off = $e.Properties[7].Value
"MODULE=$mod OFFSET=$off" | Out-File $out -Append
$file = Join-Path $bin $mod
$base = if ($mod -like '*.exe') { 0x140000000 } else { 0x180000000 }
$addr = '0x{0:x}' -f ($base + [Convert]::ToInt64(($off -replace '^0x',''),16))
"ADDR=$addr" | Out-File $out -Append
& 'C:\Program Files\LLVM\bin\llvm-symbolizer.exe' --obj="$file" --inlining --functions=linkage $addr 2>&1 | Out-File $out -Append
