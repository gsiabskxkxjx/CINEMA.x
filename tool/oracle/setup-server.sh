#!/usr/bin/env bash
# CINEMA X — تجهيز خادم ملفات الفيديو على Ubuntu (مثلاً VM مجاني على Oracle Cloud).
#
# الاستعمال (على الخادم):   sudo bash setup-server.sh <النطاق>
# مثال:                     sudo bash setup-server.sh mycinema.duckdns.org
#
# ما يفعله:
#   1) يثبّت Caddy (خادم ويب يجلب شهادة HTTPS مجانية تلقائياً)
#   2) ينشئ المجلد /srv/videos ويخدمه عبر https://<النطاق>/<اسم الملف> مع دعم Range (تقديم/ترجيع الفيديو)
#   3) لا يعرض قائمة الملفات، ولا يخدم إلا امتدادات الفيديو والترجمة
#   4) يفتح المنفذين 80 و443 في جدار الحماية المحلي (iptables) ويحفظهما
# لا يرسل أي بيانات إلى أي جهة، ولا يخزّن أي مفاتيح.
#
# قبل التشغيل: يجب أن يشير النطاق (A record) إلى عنوان IP العام للخادم، وأن تفتح المنفذين
# 80 و443 في قواعد الشبكة عند المزود (Oracle: VCN ← Security List ← Ingress Rules).
set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "الاستعمال: sudo bash $0 <النطاق>   مثال: sudo bash $0 mycinema.duckdns.org" >&2
  exit 1
fi
if ! [[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || [[ "$DOMAIN" != *.* ]]; then
  echo "النطاق غير صالح: $DOMAIN" >&2
  exit 1
fi
if [ "$(id -u)" -ne 0 ]; then
  echo "شغّل السكربت بـ sudo." >&2
  exit 1
fi

OWNER="${SUDO_USER:-ubuntu}"
VIDEO_DIR=/srv/videos
export DEBIAN_FRONTEND=noninteractive

echo "==> 1/5 تثبيت Caddy"
apt-get update -y
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gpg
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' >/etc/apt/sources.list.d/caddy-stable.list
  apt-get update -y
  apt-get install -y caddy
fi

echo "==> 2/5 مجلد الفيديو: $VIDEO_DIR (مالكه: $OWNER)"
mkdir -p "$VIDEO_DIR"
chown "$OWNER":"$OWNER" "$VIDEO_DIR"
chmod 755 /srv "$VIDEO_DIR"

echo "==> 3/5 ضبط Caddy لـ $DOMAIN"
cat >/etc/caddy/Caddyfile.tmpl <<'CADDY'
__DOMAIN__ {
	root * /srv/videos

	# لا نخدم إلا الفيديو والترجمة؛ أي شيء آخر 404 (ولا توجد قائمة ملفات)
	@blocked {
		not path_regexp \.(mp4|m4v|webm|mov|mkv|vtt|srt)$
	}
	respond @blocked 404

	header {
		Cache-Control "public, max-age=3600"
		Access-Control-Allow-Origin "*"
		-Server
	}

	file_server
}
CADDY
sed "s/__DOMAIN__/${DOMAIN}/" /etc/caddy/Caddyfile.tmpl >/etc/caddy/Caddyfile
rm -f /etc/caddy/Caddyfile.tmpl
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

echo "==> 4/5 فتح المنفذين 80 و443 في جدار الحماية المحلي"
if command -v iptables >/dev/null 2>&1; then
  open_port() {
    local p="$1" n
    iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null && return 0
    # نضعها قبل قاعدة REJECT التي تأتي مع صور Oracle، وإلا لا يكون لها أثر
    n="$(iptables -L INPUT --line-numbers -n | awk '$2=="REJECT"{print $1; exit}')"
    if [ -n "$n" ]; then
      iptables -I INPUT "$n" -p tcp --dport "$p" -j ACCEPT
    else
      iptables -A INPUT -p tcp --dport "$p" -j ACCEPT
    fi
  }
  open_port 80
  open_port 443
  apt-get install -y iptables-persistent
  netfilter-persistent save
fi

echo "==> 5/5 تشغيل Caddy"
systemctl enable caddy
systemctl restart caddy

PUBLIC_IP="$(curl -4 -fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
RESOLVED="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"
echo
echo "================ تم ================"
echo "مجلد الأفلام  : $VIDEO_DIR"
echo "الرابط        : https://$DOMAIN/<اسم الملف>"
if [ -n "$PUBLIC_IP" ] && [ -n "$RESOLVED" ] && [ "$PUBLIC_IP" != "$RESOLVED" ]; then
  echo "تحذير: النطاق يشير إلى $RESOLVED لكن عنوان هذا الخادم $PUBLIC_IP. صحّح سجل A وإلا لن تصدر الشهادة."
elif [ -z "$RESOLVED" ]; then
  echo "تحذير: النطاق لا يُحَلّ بعد. اضبط سجل A ليشير إلى ${PUBLIC_IP:-عنوان الخادم}، وستصدر الشهادة تلقائياً بعد ذلك."
fi
echo "الشهادة تُجلب عند أول طلب HTTPS؛ تابع السجل بـ: sudo journalctl -u caddy -f"
