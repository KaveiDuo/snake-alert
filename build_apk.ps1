# Builds the Snake Alert APK on this PC.
#   powershell -File build_apk.ps1            -> SnakeAlert.apk (the main app)
#   powershell -File build_apk.ps1 -Copy 01   -> SnakeAlert_01.apk, installs as a separate
#                                                "Snake Alert 01" next to the main app
param([string]$Copy = '')
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
$out = 'SnakeAlert.apk'
if ($Copy) {
    # Own app ID and name, read by android/app/build.gradle.kts.
    $env:APP_ID_SUFFIX = ".v$Copy"
    $env:APP_LABEL = "Snake Alert $Copy"
    $out = "SnakeAlert_$Copy.apk"
}
# Optional backup scanner (Groq), from groq_key.txt (not committed), also reversed.
$groqFile = Join-Path $here 'groq_key.txt'
$groqR = ''
if (Test-Path $groqFile) {
    $g = (Get-Content $groqFile -Raw).Trim()
    $gc = $g.ToCharArray(); [array]::Reverse($gc); $groqR = -join $gc
}
flutter build apk --release "--dart-define=SCANNER_KEY_R=$keyR" "--dart-define=GROQ_KEY_R=$groqR"
Remove-Item Env:APP_ID_SUFFIX, Env:APP_LABEL -ErrorAction SilentlyContinue
Copy-Item "$here\build\app\outputs\flutter-apk\app-release.apk" "$here\$out" -Force
Write-Host "APK ready: $here\$out"
