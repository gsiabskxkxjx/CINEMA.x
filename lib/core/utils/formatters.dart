/// 1:05:09 أو 05:09
String fmtClock(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "2س 15د" أو "2h 15m"
String fmtRuntime(int? minutes, bool ar) {
  if (minutes == null || minutes <= 0) return '';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hs = ar ? 'س' : 'h';
  final ms = ar ? 'د' : 'm';
  if (h > 0 && m > 0) return '$h$hs $m$ms';
  if (h > 0) return '$h$hs';
  return '$m$ms';
}

/// "قبل 3 ساعات" / "3h ago"
String fmtTimeAgo(DateTime time, bool ar) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return ar ? 'الآن' : 'just now';
  if (diff.inMinutes < 60) {
    final n = diff.inMinutes;
    return ar ? 'قبل $n د' : '${n}m ago';
  }
  if (diff.inHours < 24) {
    final n = diff.inHours;
    return ar ? 'قبل $n س' : '${n}h ago';
  }
  if (diff.inDays < 30) {
    final n = diff.inDays;
    return ar ? 'قبل $n يوم' : '${n}d ago';
  }
  final months = diff.inDays ~/ 30;
  return ar ? 'قبل $months شهر' : '${months}mo ago';
}

/// 12500 → 12.5K
String fmtCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// يستخرج امتداد الملف من رابط (بدون الاستعلام).
String urlExtension(String url) {
  final clean = url.split('?').first.split('#').first;
  final dot = clean.lastIndexOf('.');
  if (dot == -1 || dot == clean.length - 1) return '';
  return clean.substring(dot + 1).toLowerCase();
}

/// يخمّن نوع مصدر الفيديو من الرابط: hls / dash / mp4
String guessSourceType(String url) {
  final ext = urlExtension(url);
  if (ext == 'm3u8') return 'hls';
  if (ext == 'mpd') return 'dash';
  return 'mp4';
}

/// يخمّن صيغة الترجمة من الرابط: vtt / srt
String guessSubtitleFormat(String url) => urlExtension(url) == 'vtt' ? 'vtt' : 'srt';

/// يحوّل رابط مشاركة Dropbox لملف إلى رابط تنزيل مباشر (dl=1) قابل للتشغيل في المشغّل.
/// رابط المشاركة العادي (dl=0) يفتح صفحة HTML فلا يشتغل كفيديو. الروابط الأخرى
/// (وروابط مجلدات Dropbox) تبقى كما هي.
String normalizeSourceUrl(String input) {
  final raw = input.trim();
  final u = Uri.tryParse(raw);
  if (u == null || (u.scheme != 'http' && u.scheme != 'https') || u.host.isEmpty) return raw;
  final host = u.host.toLowerCase();
  if (host != 'dropbox.com' && !host.endsWith('.dropbox.com')) return raw;
  // روابط المجلدات: /sh/… و /scl/fo/… (تنزيلها يعطي ملف zip لا فيديو)
  final segs = u.pathSegments;
  if (segs.isNotEmpty && segs.first == 'sh') return raw;
  if (segs.length > 1 && segs.first == 'scl' && segs[1] == 'fo') return raw;
  final qp = Map<String, String>.from(u.queryParameters)..remove('raw');
  qp['dl'] = '1';
  return u.replace(scheme: 'https', queryParameters: qp).toString();
}

/// هل الرابط http/https صالح؟
bool isValidHttpUrl(String? url) {
  if (url == null) return false;
  final u = Uri.tryParse(url.trim());
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}

final RegExp _arabicMarks = RegExp('[ً-ٰٟـ]');

/// توحيد النص العربي/اللاتيني للبحث المحلي: إزالة التشكيل وتوحيد الألف والياء والتاء المربوطة.
String normalizeSearch(String input) {
  var t = input.replaceAll(_arabicMarks, '');
  const from = 'أإآٱىةؤئ';
  const to = 'اااايهوي';
  final b = StringBuffer();
  for (final rune in t.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    b.write(i == -1 ? ch : to[i]);
  }
  t = b.toString().toLowerCase().trim();
  return t;
}
