# Builds the Snake Alert APK on this PC.
# Java can't use the default Temp folder here (the Windows user folder has a space in its name),
# so the build uses a local .tmp folder instead.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$tmp = Join-Path $here '.tmp'
New-Item -ItemType Directory -Force $tmp | Out-Null
$env:TEMP = $tmp
$env:TMP = $tmp
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=$tmp -Djava.io.tmpdir=$tmp"
Set-Location $here
# The scanner's free Gemini key comes from scanner_key.txt (not committed), passed in reversed.
$keyFile = Join-Path $here 'scanner_key.txt'
$keyR = ''
if (Test-Path $keyFile) {
    $key = (Get-Content $keyFile -Raw).Trim()
    $chars = $key.ToCharArray(); [array]::Reverse($chars); $keyR = -join $chars
}
flutter build apk --release "--dart-define=SCANNER_KEY_R=$keyR"
Copy-Item "$here\build\app\outputs\flutter-apk\app-release.apk" "$here\SnakeAlert.apk" -Force
Write-Host "APK ready: $here\SnakeAlert.apk"
