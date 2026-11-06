# Replaces test\widget_test.dart with the resolved version.
# Run from the project root.
$src = Join-Path $PSScriptRoot "widget_test.dart"
$dst = Join-Path (Get-Location) "test\widget_test.dart"
if (-not (Test-Path $src)) { Write-Host "ERROR: widget_test.dart missing next to the script"; exit 1 }
if (-not (Test-Path $dst)) { Write-Host "ERROR: $dst not found. Run from project root."; exit 1 }
Copy-Item $dst "$dst.bak" -Force
Copy-Item $src $dst -Force
$t = [System.IO.File]::ReadAllText($dst)
if ($t -match '<<<<<<<|>>>>>>>') { Write-Host "WARNING: markers remain" } else { Write-Host "OK: widget_test.dart fixed. Backup: widget_test.dart.bak" }
