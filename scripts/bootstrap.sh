#!/usr/bin/env bash
# تجهيز مشروع CINEMA X على جهازك (Linux / macOS / Git-Bash).
# يتطلب: Flutter SDK مثبت وموجود في PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "✗ Flutter غير مثبت أو غير موجود في PATH" >&2
  exit 1
fi

if [ ! -d android ]; then
  echo "→ إنشاء مجلد android"
  flutter create --project-name cinema_x --org com.cinemax --platforms=android .
fi

echo "→ تطبيق إعدادات Android"
dart run tool/patch_android.dart

echo "→ تحميل الحزم"
flutter pub get

echo "→ توليد أيقونة التطبيق"
dart run flutter_launcher_icons || echo "(تخطّي الأيقونة - يمكنك تشغيلها لاحقاً)"

echo "✓ المشروع جاهز. الخطوة التالية:"
echo "  cp env/dart_defines.example.json env/dart_defines.json   # ثم عدّل القيم"
echo "  flutter run --dart-define-from-file=env/dart_defines.json"
