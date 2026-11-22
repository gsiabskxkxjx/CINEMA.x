-- =====================================================================
-- CINEMA X — 04_storage.sql
-- حاويات التخزين (Buckets) وسياساتها.
--   posters / backdrops / stills / subtitles : المسؤول فقط يرفع، والجميع يقرأ عبر الرابط العام
--   avatars : كل مستخدم يرفع داخل مجلده فقط  (avatars/<user_id>/...)
-- ملاحظة: ملفات الفيديو لا تُرفع هنا افتراضياً؛ أضف روابط من CDN/تخزين ترخّص لك به.
-- =====================================================================

insert into storage.buckets (id, name, public)
values
  ('posters',   'posters',   true),
  ('backdrops', 'backdrops', true),
  ('stills',    'stills',    true),
  ('subtitles', 'subtitles', true),
  ('avatars',   'avatars',   true)
on conflict (id) do nothing;

-- قراءة (مطلوبة لعمليات upsert ولسرد الملفات للمستخدمين المسجلين)
create policy "cinemax media read"
  on storage.objects for select to authenticated
  using (bucket_id in ('posters', 'backdrops', 'stills', 'subtitles', 'avatars'));

-- المسؤول: رفع/تعديل/حذف صور المحتوى والترجمات
create policy "cinemax admin insert media"
  on storage.objects for insert to authenticated
  with check (bucket_id in ('posters', 'backdrops', 'stills', 'subtitles') and public.is_admin());

create policy "cinemax admin update media"
  on storage.objects for update to authenticated
  using (bucket_id in ('posters', 'backdrops', 'stills', 'subtitles') and public.is_admin())
  with check (bucket_id in ('posters', 'backdrops', 'stills', 'subtitles') and public.is_admin());

create policy "cinemax admin delete media"
  on storage.objects for delete to authenticated
  using (bucket_id in ('posters', 'backdrops', 'stills', 'subtitles') and public.is_admin());

-- المستخدم: صورته الشخصية داخل مجلد باسم معرّفه فقط
create policy "cinemax user insert avatar"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "cinemax user update avatar"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "cinemax user delete avatar"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
