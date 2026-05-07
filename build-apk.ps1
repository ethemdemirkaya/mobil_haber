# ┌──────────────────────────────────────────────────────────────────────┐
# │ Pusula APK builder                                                   │
# │                                                                      │
# │ .env.json'daki OPENROUTER_API_KEY'i build-time'da APK'ya gömerek    │
# │ optimize release APK üretir. Kullanıcı APK'yı kurduğunda "Varsayılan │
# │ anahtar" modu çalışır hale gelir.                                   │
# │                                                                      │
# │ Kullanım:                                                            │
# │   .\build-apk.ps1                # split-per-abi (3 APK, daha küçük) │
# │   .\build-apk.ps1 -Universal     # tek universal APK                │
# │   .\build-apk.ps1 -Debug         # debug build                       │
# └──────────────────────────────────────────────────────────────────────┘

param(
    [switch]$Universal,
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path .env.json)) {
    Write-Host "[!] .env.json bulunamadi. Once sunu yap:" -ForegroundColor Yellow
    Write-Host "    Copy-Item .env.json.example .env.json" -ForegroundColor Cyan
    Write-Host "    # .env.json'a OPENROUTER_API_KEY'i yaz" -ForegroundColor Cyan
    exit 1
}

$mode = if ($Debug) { '--debug' } else { '--release' }
$useSplit = -not $Universal

Write-Host ''
Write-Host '--- Pusula APK build ---' -ForegroundColor Cyan
Write-Host ('  Mode:          {0}' -f $mode) -ForegroundColor Cyan
Write-Host ('  Split per ABI: {0}' -f $useSplit) -ForegroundColor Cyan
Write-Host '  env file:      .env.json (build-time gomulecek)' -ForegroundColor Cyan
Write-Host ''

# Flutter komut argümanları (PowerShell @args splat)
$flutterArgs = @('build', 'apk', $mode, '--dart-define-from-file=.env.json')
if ($useSplit) { $flutterArgs += '--split-per-abi' }

& flutter @flutterArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host 'X Build basarisiz' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '+ APK uretildi:' -ForegroundColor Green

$apkDir = 'build/app/outputs/flutter-apk'
$apks = Get-ChildItem (Join-Path $apkDir '*.apk') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 4

foreach ($apk in $apks) {
    $sizeMB = [math]::Round($apk.Length / 1MB, 2)
    $line = '  {0} ({1} MB)' -f $apk.Name, $sizeMB
    Write-Host $line -ForegroundColor Green
}

Write-Host ''
Write-Host ('Yol: {0}' -f $apkDir) -ForegroundColor Cyan
Write-Host ''
