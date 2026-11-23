-- =====================================================================
-- CINEMA X — 07_tmdb.sql
-- أعمدة ربط البيانات المستوردة من TMDB (بيانات وصفية وبوسترات فقط، بدون فيديو).
-- tmdb_id فريد، فيعيد الاستيراد تحديث نفس السجل بدل تكراره.
-- آمن للتشغيل أكثر من مرة.
--
-- تذكير: شروط TMDB تتطلب إسناداً ظاهراً (موجود في صفحة «حول التطبيق»)،
-- وتجديد البيانات المخزّنة دورياً (tmdb_synced_at يوضح آخر مزامنة).
-- =====================================================================

alter table public.movies
  add column if not exists tmdb_id int unique,
  add column if not exists tmdb_synced_at timestamptz;

alter table public.series
  add column if not exists tmdb_id int unique,
  add column if not exists tmdb_synced_at timestamptz;

alter table public.actors
  add column if not exists tmdb_id int unique;
