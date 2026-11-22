قوالب توقيع Android (لا تُطبَّق تلقائياً لأن شكل build.gradle يختلف بين إصدارات Flutter):

1) أنشئ مفتاح التوقيع مرة واحدة واحتفظ به بأمان (فقدانه يمنعك من تحديث التطبيق على Google Play):
   keytool -genkey -v -keystore cinemax-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cinemax
   ضع الملف في مجلد android/ (بجانب key.properties).
2) انسخ key.properties.example إلى android/key.properties وعدّل القيم.
3) طبّق المقطع المناسب لملفك: build.gradle.kts.snippet (الأحدث) أو build.gradle.snippet.
4) ابنِ:  flutter build appbundle --release --dart-define-from-file=env/dart_defines.json

ملاحظة: إن فعّلت minifyEnabled فاختبر التشغيل الفعلي للفيديو على جهاز حقيقي قبل النشر.
يمكنك البدء بتعطيله (false) إن واجهت مشكلة مع مكتبة المشغّل.
