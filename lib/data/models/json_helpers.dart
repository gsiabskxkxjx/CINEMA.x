// أدوات تحويل JSON آمنة (لا تنهار عند وجود null أو نوع غير متوقع).

String? jStr(Object? v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

int? jInt(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? jDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool jBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

DateTime? jDate(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

List<String> jStrList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

Map<String, dynamic>? jMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> jMapList(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
