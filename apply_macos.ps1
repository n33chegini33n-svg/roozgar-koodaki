foreach($f in 'macos\Runner\DebugProfile.entitlements','macos\Runner\Release.entitlements'){
  $t=[IO.File]::ReadAllText($f)
  if($t.Contains('network.client')){ "skip $f"; continue }
  $add="`t<key>com.apple.security.network.client</key>`n`t<true/>`n</dict>"
  [IO.File]::WriteAllText($f,$t.Replace('</dict>',$add))
  "ok $f"
}
