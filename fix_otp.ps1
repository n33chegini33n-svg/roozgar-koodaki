$p='lib\auth\otp_page.dart'
Copy-Item $p "$p.bak2" -Force
$o=New-Object System.Collections.Generic.List[string]
$m='n'
foreach($l in [System.IO.File]::ReadAllLines($p,[System.Text.Encoding]::UTF8)){
if($l.StartsWith('<<<<<<< ')){$m='h';continue}
if($l.StartsWith('=======') -and $m -eq 'h'){$m='t';continue}
if($l.StartsWith('>>>>>>> ') -and $m -eq 't'){$m='n';continue}
if($m -ne 't'){$o.Add($l)}
}
[System.IO.File]::WriteAllLines($p,$o,(New-Object System.Text.UTF8Encoding($false)))
git diff --check -- lib/auth/otp_page.dart
