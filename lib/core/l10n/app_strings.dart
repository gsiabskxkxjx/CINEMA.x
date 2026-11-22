import 'package:flutter/widgets.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

/// ترجمة بسيطة (عربي/إنجليزي) بدون توليد كود.
class AppStrings {
  const AppStrings(this.isAr);

  final bool isAr;

  String t(String key) => (isAr ? kStringsAr[key] : kStringsEn[key]) ?? kStringsEn[key] ?? key;

  /// يستبدل {name} بالقيم.
  String tf(String key, Map<String, Object> args) {
    var out = t(key);
    args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }
}

extension AppL10n on BuildContext {
  bool get isAr => Localizations.localeOf(this).languageCode == 'ar';

  String tr(String key) => AppStrings(isAr).t(key);

  String trf(String key, Map<String, Object> args) => AppStrings(isAr).tf(key, args);
}
