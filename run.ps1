# Pusula geliştirici çalıştırıcısı
#
# Kullanım:
#   .\run.ps1                  # debug mode
#   .\run.ps1 --profile        # profile mode
#   .\run.ps1 -d <device-id>   # belirli bir cihaza
#
# `.env.json` dosyasından OPENROUTER_API_KEY ve diğer build-time
# constant'ları otomatik enjekte eder. .env.json gitignored.

if (-not (Test-Path .env.json)) {
    Write-Host "[!] .env.json bulunamadı. .env.json.example'i .env.json olarak kopyalayıp anahtarınızı girin:" -ForegroundColor Yellow
    Write-Host "    Copy-Item .env.json.example .env.json" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Anahtarsız da çalışabilir; AI özet/sesli brifing kapalı görünür." -ForegroundColor DarkGray
    Write-Host ""
}

flutter run --dart-define-from-file=.env.json @args
