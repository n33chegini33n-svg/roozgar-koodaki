$f='lib\parent\parent_home_page.dart'
$t=[IO.File]::ReadAllText($f)
$a='EdgeInsets.fromLTRB(20, 14, 20, 28)'
if($t.Contains($a)){ [IO.File]::WriteAllText($f,$t.Replace($a,'EdgeInsets.fromLTRB(20, 14, 20, 220)')); 'ok' } else { 'NOT FOUND' }
