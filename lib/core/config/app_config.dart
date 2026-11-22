/// إعدادات التشغيل. تُمرَّر القيم وقت البناء عبر --dart-define-from-file
/// ولا تُكتب أبداً داخل الكود.
///
/// ⚠️ مفتاح SUPABASE_ANON_KEY (أو publishable key) مصمم ليكون عاماً في التطبيق.
/// أمّا مفتاح service_role فيجب ألا يوضع هنا إطلاقاً.
class AppConfig {
  AppConfig._();

  static const String appName = 'CINEMA X';
  static const String version = '1.0.0';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// إجبار الوضع التجريبي حتى لو كانت مفاتيح Supabase موجودة.
  static const bool forceDemo = bool.fromEnvironment('FORCE_DEMO');

  /// رابط الرجوع بعد التحقق من البريد/استعادة كلمة المرور (يجب إضافته في Supabase → Auth → URL Configuration).
  static const String authRedirect = 'io.cinemax.app://login-callback';

  static bool get hasBackend =>
      !forceDemo && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// حجم الصفحة في الشبكات (Pagination).
  static const int pageSize = 24;

  /// عدد العناصر في كل صف أفقي بالصفحة الرئيسية.
  static const int rowSize = 15;
}
