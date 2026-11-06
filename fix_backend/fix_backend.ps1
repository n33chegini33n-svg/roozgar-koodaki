# Resolves the merge conflict in lib\services\backend.dart
# Run from the project root. Needs backend_block.txt next to this script.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$path = Join-Path (Get-Location) "lib\services\backend.dart"
$blockFile = Join-Path $PSScriptRoot "backend_block.txt"
if (-not (Test-Path $path)) { Write-Host "ERROR: $path not found. Run from project root."; exit 1 }
if (-not (Test-Path $blockFile)) { Write-Host "ERROR: backend_block.txt missing next to the script."; exit 1 }

$text = [System.IO.File]::ReadAllText($path, $utf8)
[System.IO.File]::WriteAllText("$path.bak", $text, $utf8)

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }
$block = ([System.IO.File]::ReadAllText($blockFile, $utf8)) -replace "`r?`n", $nl

$pattern = '(?s)  static Future<void> signOut\(\) async \{.*?UserDirectory\.clearCache\(\);\r?\n  \}'
if ($text -notmatch $pattern) { Write-Host "ERROR: signOut block not found. Nothing changed."; exit 1 }

$result = [regex]::Replace($text, $pattern, { param($m) $block })
[System.IO.File]::WriteAllText($path, $result, $utf8)

if ($result -match '<<<<<<<|>>>>>>>|=======') { Write-Host "WARNING: markers remain" } else { Write-Host "OK: backend.dart fixed. Backup: backend.dart.bak" }
