import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import 'admin_repository.dart';

// ---------------------------------------------------------------------- مساعدات تحويل
/// نص فارغ → null.
String? nz(String? v) {
  final t = (v ?? '').trim();
  return t.isEmpty ? null : t;
}

int? toInt(String? v) => int.tryParse((v ?? '').trim());

double? toDouble(String? v) => double.tryParse((v ?? '').trim().replaceAll(',', '.'));

/// حقل اختياري يقبل عدداً صحيحاً ضمن [min, max].
String? Function(String?) optionalInt(BuildContext context, {int min = 0, int max = 1 << 31}) {
  return (v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < min || n > max) return context.tr('v_number_range');
    return null;
  };
}

String? Function(String?) requiredInt(BuildContext context, {int min = 0, int max = 1 << 31}) {
  return (v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return context.tr('v_required');
    final n = int.tryParse(t);
    if (n == null || n < min || n > max) return context.tr('v_number_range');
    return null;
  };
}

String? Function(String?) optionalUrl(BuildContext context) {
  return (v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return isValidHttpUrl(t) ? null : context.tr('v_url');
  };
}

String? Function(String?) requiredUrl(BuildContext context) {
  return (v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return context.tr('v_required');
    return isValidHttpUrl(t) ? null : context.tr('v_url');
  };
}

// ---------------------------------------------------------------------- عناصر واجهة
class AdminLabel extends StatelessWidget {
  const AdminLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13.5),
      ),
    );
  }
}

/// حقل اختيار من قائمة (بديل عن Dropdown لتفادي اختلاف الإصدارات).
class ChoiceField<T extends Object> extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final T? value;
  final List<ChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.value == value).firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final v = await showChoiceSheet<T>(context, title: label, options: options, selected: value);
        if (v != null) onChanged(v);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.card,
          labelStyle: const TextStyle(color: AppColors.textDim),
          prefixIcon: icon == null ? null : Icon(icon, size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
        ),
        child: Text(current?.label ?? '—'),
      ),
    );
  }
}

class AdminSwitch extends StatelessWidget {
  const AdminSwitch({super.key, required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// حقل صورة: رابط يدوي أو رفع من المعرض إلى حاوية Supabase.
class ImageUploadField extends ConsumerStatefulWidget {
  const ImageUploadField({
    super.key,
    required this.label,
    required this.controller,
    required this.bucket,
    this.folder = 'content',
    this.aspectRatio = 2 / 3,
    this.previewWidth = 90,
  });

  final String label;
  final TextEditingController controller;
  final String bucket;
  final String folder;
  final double aspectRatio;
  final double previewWidth;

  @override
  ConsumerState<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends ConsumerState<ImageUploadField> {
  bool _uploading = false;

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 88);
      if (file == null) return;
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      final dot = file.name.lastIndexOf('.');
      final ext = dot == -1 ? 'jpg' : file.name.substring(dot + 1);
      final url = await ref.read(adminRepoProvider).uploadImage(
            bucket: widget.bucket,
            bytes: bytes,
            extension: ext,
            folder: widget.folder,
          );
      if (!mounted) return;
      widget.controller.text = url;
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.previewWidth;
    final h = w / widget.aspectRatio;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(url: v.text.trim(), width: w, height: h),
                  if (_uploading)
                    const ColoredBox(
                      color: Colors.black54,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: widget.controller,
                label: widget.label,
                hint: 'https://…',
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                validator: optionalUrl(context),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pick,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text(context.tr('upload_image')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// حالة تحميل/خطأ/فراغ لقوائم المسؤول.
class AdminAsyncList<T> extends StatelessWidget {
  const AdminAsyncList({
    super.key,
    required this.async,
    required this.onRetry,
    required this.builder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle,
  });

  final AsyncValue<List<T>> async;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, List<T>) builder;
  final IconData emptyIcon;
  final String? emptyTitle;

  @override
  Widget build(BuildContext context) {
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
      data: (items) => items.isEmpty
          ? EmptyState(icon: emptyIcon, title: emptyTitle ?? context.tr('admin_empty'))
          : builder(context, items),
    );
  }
}

/// تشغيل عملية كتابة مع إظهار الخطأ وإعادة true عند النجاح.
Future<bool> runAdminAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (context.mounted && success != null) showAppSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showAppSnack(context, friendlyError(context, e), error: true);
    return false;
  }
}

/// كل الأنواع الفنية (للاختيار في النماذج).
final adminGenresProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepoProvider).genres(),
);
