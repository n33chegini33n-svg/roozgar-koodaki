$f='lib\models\user_directory.dart'
$t=[IO.File]::ReadAllText($f)
$t=$t.Replace("id, full_name, role, phone, grade, active, classes(name)","id, full_name, role, phone, active, classes(name)").Replace("(p['grade'] ?? '')","''")
[IO.File]::WriteAllText($f,$t)
Select-String -Path lib\*.dart,lib\*\*.dart -Pattern "grade" | Select-Object -ExpandProperty Line
