#!/usr/bin/env bash
# CINEMA X — يرفع ملف فيديو من جهازك إلى خادم الفيديو (setup-server.sh) ويطبع الرابط.
#
# الاستعمال:  bash upload-video.sh <الملف> <user@host> <النطاق>
# مثال:       bash upload-video.sh film.mp4 ubuntu@203.0.113.7 mycinema.duckdns.org
#
# - يعطي الملف اسماً عشوائياً (الرابط لا يُخمَّن)، ويحفظ الاسم بجوار الملف الأصلي فتستأنف
#   إعادةُ تشغيل الأمر الرفعَ من حيث توقف إذا انقطع الاتصال (rsync --partial).
# - يحتاج ssh وrsync (Linux / macOS / WSL على ويندوز). على ويندوز العادي استخدم WinSCP (يدعم الاستئناف)
#   وارفع إلى /srv/videos بالاسم الذي تريده.
# - ارفع فقط ما تملك حقوقه أو مرخّصاً لك.
set -euo pipefail

FILE="${1:-}"
TARGET="${2:-}"
DOMAIN="${3:-}"
if [ -z "$FILE" ] || [ -z "$TARGET" ] || [ -z "$DOMAIN" ]; then
  echo "الاستعمال: bash $0 <الملف> <user@host> <النطاق>" >&2
  exit 1
fi
[ -f "$FILE" ] || { echo "الملف غير موجود: $FILE" >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync غير مثبّت." >&2; exit 1; }

EXT="${FILE##*.}"
EXT="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"
case "$EXT" in
  mp4|m4v|webm|mov|mkv) ;;
  *) echo "الصيغة غير مدعومة: .$EXT (المسموح: mp4 m4v webm mov mkv)" >&2; exit 1 ;;
esac

NAME_FILE="$FILE.cinemax-name"
if [ -s "$NAME_FILE" ]; then
  NAME="$(cat "$NAME_FILE")"
else
  NAME="$(od -An -N10 -tx1 /dev/urandom | tr -d ' \n').$EXT"
  printf '%s' "$NAME" >"$NAME_FILE"
fi

echo "==> رفع $FILE ← $TARGET:/srv/videos/$NAME"
rsync -avP --partial -e ssh "$FILE" "$TARGET:/srv/videos/$NAME"

echo
echo "تم. الصق هذا الرابط في التطبيق (روابط الفيديو ← + ← من رابط):"
echo "https://$DOMAIN/$NAME"
