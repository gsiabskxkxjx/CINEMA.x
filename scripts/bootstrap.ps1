# تجهيز مشروع CINEMA X على Windows (PowerShell).
# يتطلب: Flutter SDK مثبت وموجود في PATH.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter غير مثبت أو غير موجود في PATH"
}

if (-not (Test-Path "android")) {
  Write-Host "-> إنشاء مجلد android"
  flutter create --project-name cinema_x --org com.cinemax --platforms=android .
}

Write-Host "-> تطبيق إعدادات Android"
dart run tool/patch_android.dart

Write-Host "-> تحميل الحزم"
flutter pub get

Write-Host "-> توليد أيقونة التطبيق"
dart run flutter_launcher_icons

Write-Host "تم. الخطوة التالية:"
Write-Host "  Copy-Item env/dart_defines.example.json env/dart_defines.json   # ثم عدّل القيم"
Write-Host "  flutter run --dart-define-from-file=env/dart_defines.json"
