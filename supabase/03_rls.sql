-- =====================================================================
-- CINEMA X — 03_rls.sql
-- Row Level Security: المستخدم العادي يقرأ فقط (ويدير بياناته الشخصية)،
-- والمسؤول (profiles.role = 'admin') يدير كل شيء.
-- =====================================================================

-- ---------------------------------------------------------------------
-- تفعيل RLS على كل الجداول
-- ---------------------------------------------------------------------
alter table public.profiles           enable row level security;
alter table public.genres             enable row level security;
alter table public.categories         enable row level security;
alter table public.actors             enable row level security;
alter table public.movies             enable row level security;
alter table public.series             enable row level security;
alter table public.seasons            enable row level security;
alter table public.episodes           enable row level security;
alter table public.movie_genres       enable row level security;
alter table public.series_genres      enable row level security;
alter table public.movie_actors       enable row level security;
alter table public.series_actors      enable row level security;
alter table public.video_sources      enable row level security;
alter table public.subtitles          enable row level security;
alter table public.favorites          enable row level security;
alter table public.watch_history      enable row level security;
alter table public.view_events        enable row level security;
alter table public.app_settings       enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.subscriptions      enable row level security;
alter table public.payments           enable row level security;
alter table public.user_devices       enable row level security;

-- ---------------------------------------------------------------------
-- المسؤول: صلاحية كاملة على جداول المحتوى والإعدادات
-- (video_sources هنا مقروءة للمسؤول فقط)
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'genres', 'categories', 'actors', 'movies', 'series', 'seasons', 'episodes',
    'movie_genres', 'series_genres', 'movie_actors', 'series_actors',
    'video_sources', 'subtitles', 'app_settings', 'subscription_plans'
  ] loop
    execute format(
      'create policy %I on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())',
      t || '_admin_all', t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- القراءة للمستخدمين المسجلين فقط (لا قراءة للزائر المجهول)
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'genres', 'categories', 'actors', 'seasons',
    'movie_genres', 'series_genres', 'movie_actors', 'series_actors', 'subtitles'
  ] loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (true)',
      t || '_read', t
    );
  end loop;
end $$;

create policy movies_read   on public.movies   for select to authenticated using (is_published);
create policy series_read   on public.series   for select to authenticated using (is_published);
create policy episodes_read on public.episodes for select to authenticated using (is_published);

-- الخطط المفعّلة فقط
create policy plans_read on public.subscription_plans
  for select to authenticated using (is_active);

-- إعدادات التطبيق عامة القراءة (وضع الصيانة...). لا تضع أسراراً فيها.
create policy app_settings_read on public.app_settings
  for select to anon, authenticated using (true);

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_select_admin on public.profiles
  for select to authenticated using (public.is_admin());
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy profiles_update_admin on public.profiles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
-- (تغيير role / is_blocked / email محمي بمشغّل protect_profile_fields)

-- ---------------------------------------------------------------------
-- بيانات المستخدم الشخصية
-- ---------------------------------------------------------------------
create policy favorites_own on public.favorites
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy watch_history_own on public.watch_history
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy user_devices_select_own on public.user_devices
  for select to authenticated using (user_id = (select auth.uid()));
create policy user_devices_delete_own on public.user_devices
  for delete to authenticated using (user_id = (select auth.uid()));
create policy user_devices_admin_select on public.user_devices
  for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------
-- الاشتراكات والمدفوعات: قراءة الخاص بي فقط. الكتابة تتم من الخادم (service role)
-- عند ربط مزود دفع حقيقي لاحقاً، وليس من التطبيق.
-- ---------------------------------------------------------------------
create policy subscriptions_select_own on public.subscriptions
  for select to authenticated using (user_id = (select auth.uid()));
create policy subscriptions_admin_select on public.subscriptions
  for select to authenticated using (public.is_admin());

create policy payments_select_own on public.payments
  for select to authenticated using (user_id = (select auth.uid()));
create policy payments_admin_select on public.payments
  for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------
-- أحداث المشاهدة: قراءة المسؤول فقط. الإدراج عبر log_view (SECURITY DEFINER).
-- ---------------------------------------------------------------------
create policy view_events_admin_select on public.view_events
  for select to authenticated using (public.is_admin());
