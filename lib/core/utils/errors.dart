import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';

/// خطأ تطبيق يحمل مفتاح رسالة مترجمة.
class AppException implements Exception {
  const AppException(this.key);
  final String key;

  @override
  String toString() => 'AppException($key)';
}

/// رسالة خطأ مفهومة للمستخدم بلغة التطبيق.
String friendlyError(BuildContext context, Object error) =>
    context.tr(errorKey(error));

/// يحوّل أي استثناء إلى مفتاح ترجمة.
String errorKey(Object e) {
  if (e is AppException) return e.key;
  if (e is SocketException || e is TimeoutException || e is HandshakeException) {
    return 'err_network';
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (e.runtimeType.toString().contains('Retryable') ||
        m.contains('socketexception') ||
        m.contains('failed host lookup') ||
        m.contains('clientexception')) {
      return 'err_network';
    }
    if (m.contains('invalid login credentials') || m.contains('invalid credentials')) {
      return 'err_invalid_credentials';
    }
    if (m.contains('email not confirmed')) return 'err_email_not_confirmed';
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'err_user_exists';
    }
    if (m.contains('password should be') || m.contains('weak password')) {
      return 'err_weak_password';
    }
    if (m.contains('rate limit') || m.contains('too many')) return 'err_rate_limit';
    if (m.contains('same password')) return 'err_same_password';
    return 'err_generic';
  }
  if (e is PostgrestException) {
    final m = e.message.toLowerCase();
    if (m.contains('premium_required')) return 'err_premium_required';
    if (m.contains('account_blocked')) return 'err_blocked';
    if (m.contains('not_authenticated')) return 'err_not_authenticated';
    if (m.contains('device_limit_reached')) return 'err_device_limit';
    if (m.contains('not_found')) return 'err_not_found';
    switch (e.code) {
      case '42501':
        return 'err_forbidden';
      case 'PGRST116':
        return 'err_not_found';
      case '23505':
        return 'err_duplicate';
      case '23503':
        return 'err_in_use';
      case '23514':
        return 'err_invalid_value';
    }
    return 'err_generic';
  }
  if (e is StorageException) {
    return 'err_upload';
  }
  final s = e.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('clientexception') ||
      s.contains('connection closed') ||
      s.contains('connection refused') ||
      s.contains('network is unreachable')) {
    return 'err_network';
  }
  return 'err_generic';
}
