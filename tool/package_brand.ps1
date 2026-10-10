$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
function Export-Size([string]$source, [string]$destination, [int]$size) {
    $inputImage = [System.Drawing.Image]::FromFile($source)
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($inputImage, 0, 0, $size, $size)
    $graphics.Dispose()
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $inputImage.Dispose()
}
$master = Join-Path $projectRoot 'docs/design/screenshots/launcher-master.png'
Export-Size $master (Join-Path $projectRoot 'assets/brand/app-icon.png') 1024
$densities = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($density in $densities.Keys) {
    Export-Size $master (Join-Path $projectRoot "android/app/src/main/res/mipmap-$density/ic_launcher.png") $densities[$density]
}
$iconDir = Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
$catalog = Get-Content -Raw (Join-Path $iconDir 'Contents.json') | ConvertFrom-Json
foreach ($entry in $catalog.images) {
    $size = [int]([double]($entry.size.Split('x')[0]) * [double]($entry.scale.TrimEnd('x')))
    Export-Size $master (Join-Path $iconDir $entry.filename) $size
}
$launchDir = Join-Path $projectRoot 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
$launch = Join-Path $projectRoot 'docs/design/screenshots/native-launch-mascot.png'
Export-Size $launch (Join-Path $launchDir 'LaunchImage.png') 288
Export-Size $launch (Join-Path $launchDir 'LaunchImage@2x.png') 576
Export-Size $launch (Join-Path $launchDir 'LaunchImage@3x.png') 864
$nativeDir = Join-Path $projectRoot 'android/app/src/main/res/drawable-nodpi'
New-Item -ItemType Directory -Path $nativeDir -Force | Out-Null
Copy-Item -LiteralPath $launch -Destination (Join-Path $nativeDir 'pusula_launch_mascot.png') -Force
Write-Output 'Launcher icons and mascot launch assets packaged for Android and iOS.'
