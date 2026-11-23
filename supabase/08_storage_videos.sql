-- =====================================================================
-- CINEMA X — 08_storage_videos.sql   (اختياري: رفع فيديو من المعرض)
-- حاوية videos لملفات فيديو يرفعها المسؤول من لوحة الإدارة.
--
-- ⚠️ حدود Supabase:
--   * الخطة المجانية: 50 MB للملف الواحد و 1 GB تخزين كلي (لا يمكن رفع الحدّ).
--   * الخطة Pro: حدّ أعلى (يُضبط من Storage → Settings)، والملفات الكبيرة تحتاج
--     رفعاً قابلاً للاستئناف (TUS) وهو غير مُنفَّذ في التطبيق حالياً.
--   * رفع فيلم كامل يحتاج عادةً استضافة فيديو مخصصة (Bunny / Cloudflare Stream / Mux).
--
-- الأمان:
--   * الحاوية عامة (الروابط عامة)، وأسماء الملفات عشوائية. الروابط لا تصل المستخدمين إلا
--     عبر الدالة get_playback_sources، لكن من يحصل على رابط ملف يستطيع فتحه مباشرة؛
--     أي قيد Premium لا يحمي الملف نفسه إذا تسرّب رابطه.
--   * رفع/حذف/قراءة القائمة: المسؤول فقط.
-- آمن للتشغيل أكثر من مرة.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'videos', 'videos', true, 52428800,
  array['video/mp4', 'video/webm', 'video/quicktime', 'video/x-matroska']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "cinemax admin select videos" on storage.objects;
drop policy if exists "cinemax admin insert videos" on storage.objects;
drop policy if exists "cinemax admin update videos" on storage.objects;
drop policy if exists "cinemax admin delete videos" on storage.objects;

create policy "cinemax admin select videos"
  on storage.objects for select to authenticated
  using (bucket_id = 'videos' and public.is_admin());

create policy "cinemax admin insert videos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'videos' and public.is_admin());

create policy "cinemax admin update videos"
  on storage.objects for update to authenticated
  using (bucket_id = 'videos' and public.is_admin())
  with check (bucket_id = 'videos' and public.is_admin());

create policy "cinemax admin delete videos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'videos' and public.is_admin());

-- الحد الأقصى (بالميغابايت) الذي يفحصه التطبيق قبل بدء الرفع. ارفعه فقط إذا رفعت حدّ التخزين.
insert into public.app_settings (key, value, description)
values ('max_upload_mb', '50'::jsonb, 'أقصى حجم (MB) لرفع فيديو من المعرض؛ يجب ألا يتجاوز حدّ تخزين Supabase')
on conflict (key) do nothing;
