$f='lib\auth\welcome_page.dart'
$t=[IO.File]::ReadAllText($f)
if(-not $t.Contains("'logo.jpg'")){ "NOT FOUND logo.jpg"; exit }
$t=$t.Replace("'logo.jpg'","'welcome_bg.jpg'").Replace("alignment: Alignment.topCenter,","alignment: const Alignment(0, -0.25),")
[IO.File]::WriteAllText($f,$t)
"ok"
