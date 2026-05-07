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
    Write-Host "[!] .env.json bulunamadı. Önce şunu yap:" -ForegroundColor Yellow
    Write-Host "    Copy-Item .env.json.example .env.json" -ForegroundColor Cyan
    Write-Host "    # .env.json'a OPENROUTER_API_KEY'i yaz" -ForegroundColor Cyan
    exit 1
}

$mode = if ($Debug) { "--debug" } else { "--release" }
$splitArg = if ($Universal) { "" } else { "--split-per-abi" }

Write-Host ""
Write-Host "┌─ Pusula APK build ──────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│ Mode:          $mode" -ForegroundColor Cyan
Write-Host "│ Split per ABI: $(-not $Universal)" -ForegroundColor Cyan
Write-Host "│ env file:      .env.json (build-time gömülecek)                 │" -ForegroundColor Cyan
Write-Host "└─────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

$args = @("build", "apk", $mode, "--dart-define-from-file=.env.json")
if ($splitArg) { $args += $splitArg }

flutter @args

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Build başarısız" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✓ APK üretildi:" -ForegroundColor Green
Get-ChildItem "build\app\outputs\flutter-apk\*.apk" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 4 |
    ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  $($_.Name) ($sizeMB MB)" -ForegroundColor Green
    }
Write-Host ""
Write-Host "Yol: build\app\outputs\flutter-apk\" -ForegroundColor Cyan
Write-Host ""
