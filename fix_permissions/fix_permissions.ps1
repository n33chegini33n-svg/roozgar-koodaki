# Fixes the merge conflict in lib\models\permissions.dart
# Run from the project root (D:\mehran\rooozgarkooodaki)

$path = Join-Path (Get-Location) "lib\models\permissions.dart"
if (-not (Test-Path $path)) {
    Write-Host "ERROR: file not found: $path"
    Write-Host "Run this script from the project root folder."
    exit 1
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($path, $utf8)

# backup
[System.IO.File]::WriteAllText("$path.bak", $text, $utf8)

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }

$persianComment = "/// " + [string]::Join("", @(
  [char]0x067E,[char]0x0627,[char]0x06A9,[char]0x200C,[char]0x06A9,[char]0x0631,[char]0x062F,[char]0x0646,
  [char]0x0020,
  [char]0x0647,[char]0x0648,[char]0x06CC,[char]0x062A,
  [char]0x0020,
  [char]0x0641,[char]0x0639,[char]0x0627,[char]0x0644
))

$newBlock = @(
"class Session {",
"  static AppRole role = AppRole.parent;",
"  static String userName = '';",
"  static String className = '';",
"  static String childName = '';",
"",
"  $persianComment",
"  static void reset() {",
"    role = AppRole.parent;",
"    userName = '';",
"    className = '';",
"    childName = '';",
"  }"
) -join $nl

$pattern = '(?s)class Session \{.*?\r?\n  \}(?=\r?\n\r?\n  static void signIn)'
if ($text -notmatch $pattern) {
    Write-Host "ERROR: could not find the Session block. Nothing was changed."
    exit 1
}

$result = [regex]::Replace($text, $pattern, { param($m) $newBlock })
[System.IO.File]::WriteAllText($path, $result, $utf8)

if ($result -match '<<<<<<<|>>>>>>>') {
    Write-Host "WARNING: conflict markers still exist in the file."
} else {
    Write-Host "OK: permissions.dart fixed. Backup saved as permissions.dart.bak"
}
