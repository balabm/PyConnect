# Build the Flutter web app with the API base URL pointing to localhost:5000
$ErrorActionPreference = "Stop"

$flutter = "C:\flutter\flutter\bin\flutter.bat"
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "Building Flutter web app..."
& $flutter build web `
    --dart-define=API_BASE_URL=http://localhost:5000 `
    --web-renderer canvaskit `
    --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter web build failed"
    exit 1
}

Write-Host "Flutter web build complete at $projectRoot\mobile\build\web"
