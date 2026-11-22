// يُشغَّل بعد `flutter create` لإضافة إعدادات CINEMA X إلى مجلد android.
//   dart run tool/patch_android.dart
//
// ما يفعله:
//  1) إضافة صلاحيات INTERNET و ACCESS_NETWORK_STATE.
//  2) ضبط اسم التطبيق الظاهر CINEMA X.
//  3) إضافة intent-filter لروابط الرجوع من Supabase (استعادة كلمة المرور).
//  4) إنشاء ملف proguard-rules.pro الخاص بمشغل media_kit.
//  5) تعطيل مهام lintVital (تنهار أداة lint عند فحص بعض الإضافات فيفشل بناء release).
// السكربت آمن للتشغيل أكثر من مرة (idempotent).
import 'dart:io';

const _deepLinkScheme = 'io.cinemax.app';
const _deepLinkHost = 'login-callback';

void main() {
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (!manifestFile.existsSync()) {
    stderr.writeln('لم يتم العثور على android/app/src/main/AndroidManifest.xml');
    stderr.writeln('شغّل أولاً: flutter create --project-name cinema_x --org com.cinemax --platforms=android .');
    exit(1);
  }

  var xml = manifestFile.readAsStringSync();
  final changes = <String>[];

  void addPermission(String permission) {
    if (xml.contains('android:name="$permission"')) return;
    xml = xml.replaceFirst(
      '<application',
      '<uses-permission android:name="$permission"/>\n    <application',
    );
    changes.add('permission: $permission');
  }

  addPermission('android.permission.INTERNET');
  addPermission('android.permission.ACCESS_NETWORK_STATE');

  // اسم التطبيق
  final labelRegex = RegExp(r'android:label="[^"]*"');
  if (labelRegex.hasMatch(xml) && !xml.contains('android:label="CINEMA X"')) {
    xml = xml.replaceFirst(labelRegex, 'android:label="CINEMA X"');
    changes.add('label: CINEMA X');
  }

  // روابط Supabase العميقة
  if (!xml.contains(_deepLinkHost)) {
    const filter = '''
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="$_deepLinkScheme" android:host="$_deepLinkHost"/>
            </intent-filter>
''';
    final idx = xml.indexOf('</activity>');
    if (idx != -1) {
      xml = '${xml.substring(0, idx)}$filter        ${xml.substring(idx)}';
      changes.add('deep link: $_deepLinkScheme://$_deepLinkHost');
    } else {
      stderr.writeln('تحذير: لم أجد </activity> لإضافة رابط الرجوع.');
    }
  }

  manifestFile.writeAsStringSync(xml);

  // قواعد ProGuard/R8 لمشغل media_kit (آمنة حتى لو لم يُفعّل التصغير)
  final proguard = File('android/app/proguard-rules.pro');
  if (!proguard.existsSync()) {
    proguard.writeAsStringSync('''
# قواعد CINEMA X / media_kit
-keep class com.alexmercerind.** { *; }
-keep class dev.flutter.** { *; }
-dontwarn com.alexmercerind.**
''');
    changes.add('proguard-rules.pro');
  }

  // تعطيل فحص lint الإلزامي عند بناء release:
  // أداة lint في Android Gradle Plugin تنهار (NoSuchMethodError في JavaDocParser)
  // أثناء فحص كود الإضافات مثل image_picker_android، فيفشل البناء رغم سلامة الكود.
  // هذا يعطّل مهام lintVital فقط ولا يؤثر على الترجمة أو الكود الناتج.
  const lintMarker = 'CINEMA X: disable lintVital';
  final rootKts = File('android/build.gradle.kts');
  final rootGroovy = File('android/build.gradle');
  if (rootKts.existsSync()) {
    final src = rootKts.readAsStringSync();
    if (!src.contains(lintMarker)) {
      rootKts.writeAsStringSync('''$src

// $lintMarker (lint crash in plugin modules)
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}
''');
      changes.add('build.gradle.kts: lintVital disabled');
    }
  } else if (rootGroovy.existsSync()) {
    final src = rootGroovy.readAsStringSync();
    if (!src.contains(lintMarker)) {
      rootGroovy.writeAsStringSync('''$src

// $lintMarker (lint crash in plugin modules)
subprojects {
    tasks.matching { it.name.startsWith('lintVital') }.configureEach { enabled = false }
}
''');
      changes.add('build.gradle: lintVital disabled');
    }
  } else {
    stderr.writeln('تحذير: لم أجد android/build.gradle(.kts) لتعطيل lintVital.');
  }

  if (changes.isEmpty) {
    stdout.writeln('لا توجد تغييرات - المشروع مُعدّ مسبقاً.');
  } else {
    stdout.writeln('تم تطبيق التعديلات التالية:');
    for (final c in changes) {
      stdout.writeln('  • $c');
    }
  }
}
