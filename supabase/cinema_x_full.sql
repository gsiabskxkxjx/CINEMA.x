-- CINEMA X: الملف الكامل (01..05). شغّله مرة واحدة في SQL Editor على مشروع جديد.
-- الملف 06_demo_content.sql اختياري ومنفصل.

-- >>>>>>>>>> 01_schema.sql
-- =====================================================================
-- CINEMA X — 01_schema.sql
-- الجداول والفهارس والمشغّلات (Triggers) والعرض الموحّد catalog.
-- شغّل الملفات بالترتيب 01 → 05 داخل Supabase SQL Editor
-- (أو شغّل الملف المدمج cinema_x_full.sql دفعة واحدة).
-- =====================================================================

set search_path = public, extensions;

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------
-- دوال مساعدة
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- توحيد النص العربي للبحث: إزالة التشكيل والتطويل وتوحيد الألف والياء والتاء المربوطة
create or replace function public.ar_norm(t text)
returns text language sql immutable parallel safe set search_path = '' as $$
  select lower(
    translate(
      regexp_replace(coalesce(t, ''), U&'[\064B-\065F\0670\0640]', '', 'g'),
      U&'\0623\0625\0622\0671\0649\0629\0624\0626',
      U&'\0627\0627\0627\0627\064A\0647\0648\064A'
    )
  );
$$;

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
create table public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  email             text,
  display_name      text,
  avatar_url        text,
  role              text not null default 'user' check (role in ('user', 'admin')),
  is_blocked        boolean not null default false,
  language          text not null default 'ar' check (language in ('ar', 'en')),
  preferred_quality text not null default 'auto',
  subtitle_language text not null default 'off',
  autoplay_next     boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- هل المستخدم الحالي مسؤول؟ (SECURITY DEFINER لتجنّب التكرار اللانهائي في سياسات RLS)
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and not p.is_blocked
  );
$$;

-- ---------------------------------------------------------------------
-- التصنيفات والأنواع والممثلون
-- ---------------------------------------------------------------------
create table public.genres (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique,
  name_ar    text not null,
  name_en    text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- الفئة = قاعدة تُعرض كصف في الرئيسية: (نوع العمل + الأصل + النوع الفني)
create table public.categories (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,
  name_ar      text not null,
  name_en      text not null,
  kind         text check (kind in ('movie', 'series')),
  origin       text check (origin in ('arab', 'foreign')),
  genre_id     uuid references public.genres (id) on delete set null,
  layout       text not null default 'poster' check (layout in ('poster', 'landscape')),
  sort_order   int not null default 0,
  show_on_home boolean not null default true,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

create table public.actors (
  id         uuid primary key default gen_random_uuid(),
  name_ar    text not null,
  name_en    text,
  photo_url  text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- الأفلام
-- ---------------------------------------------------------------------
create table public.movies (
  id                  uuid primary key default gen_random_uuid(),
  title_ar            text not null,
  title_en            text,
  overview_ar         text,
  overview_en         text,
  poster_url          text,
  backdrop_url        text,
  trailer_url         text,
  release_year        int check (release_year between 1888 and 2100),
  age_rating          text,
  country             text,
  language            text,
  origin              text not null default 'foreign' check (origin in ('arab', 'foreign')),
  quality             text,
  rating              numeric(3, 1) check (rating is null or (rating >= 0 and rating <= 10)),
  runtime_minutes     int check (runtime_minutes is null or runtime_minutes > 0),
  director            text,
  subtitle_languages  text[] not null default '{}',
  intro_start_seconds int check (intro_start_seconds is null or intro_start_seconds >= 0),
  intro_end_seconds   int check (intro_end_seconds is null or intro_end_seconds >= 0),
  is_featured         boolean not null default false,
  featured_order      int not null default 0,
  is_published        boolean not null default true,
  is_premium          boolean not null default false,
  view_count          bigint not null default 0,
  created_by          uuid default auth.uid() references auth.users (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- المسلسلات والمواسم والحلقات
-- ---------------------------------------------------------------------
create table public.series (
  id                 uuid primary key default gen_random_uuid(),
  title_ar           text not null,
  title_en           text,
  overview_ar        text,
  overview_en        text,
  poster_url         text,
  backdrop_url       text,
  trailer_url        text,
  release_year       int check (release_year between 1888 and 2100),
  age_rating         text,
  country            text,
  language           text,
  origin             text not null default 'foreign' check (origin in ('arab', 'foreign')),
  quality            text,
  rating             numeric(3, 1) check (rating is null or (rating >= 0 and rating <= 10)),
  runtime_minutes    int check (runtime_minutes is null or runtime_minutes > 0), -- متوسط مدة الحلقة
  director           text,
  subtitle_languages text[] not null default '{}',
  is_featured        boolean not null default false,
  featured_order     int not null default 0,
  is_published       boolean not null default true,
  is_premium         boolean not null default false,
  view_count         bigint not null default 0,
  created_by         uuid default auth.uid() references auth.users (id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table public.seasons (
  id            uuid primary key default gen_random_uuid(),
  series_id     uuid not null references public.series (id) on delete cascade,
  season_number int not null check (season_number > 0),
  title_ar      text,
  title_en      text,
  created_at    timestamptz not null default now(),
  unique (series_id, season_number)
);

create table public.episodes (
  id                  uuid primary key default gen_random_uuid(),
  season_id           uuid not null references public.seasons (id) on delete cascade,
  series_id           uuid not null references public.series (id) on delete cascade, -- يُملأ تلقائياً
  episode_number      int not null check (episode_number > 0),
  title_ar            text,
  title_en            text,
  overview_ar         text,
  overview_en         text,
  still_url           text,
  runtime_minutes     int check (runtime_minutes is null or runtime_minutes > 0),
  intro_start_seconds int check (intro_start_seconds is null or intro_start_seconds >= 0),
  intro_end_seconds   int check (intro_end_seconds is null or intro_end_seconds >= 0),
  air_date            date,
  is_published        boolean not null default true,
  view_count          bigint not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (season_id, episode_number)
);

-- ---------------------------------------------------------------------
-- الروابط (many-to-many)
-- ---------------------------------------------------------------------
create table public.movie_genres (
  movie_id uuid not null references public.movies (id) on delete cascade,
  genre_id uuid not null references public.genres (id) on delete cascade,
  primary key (movie_id, genre_id)
);

create table public.series_genres (
  series_id uuid not null references public.series (id) on delete cascade,
  genre_id  uuid not null references public.genres (id) on delete cascade,
  primary key (series_id, genre_id)
);

create table public.movie_actors (
  movie_id       uuid not null references public.movies (id) on delete cascade,
  actor_id       uuid not null references public.actors (id) on delete cascade,
  character_name text,
  sort_order     int not null default 0,
  primary key (movie_id, actor_id)
);

create table public.series_actors (
  series_id      uuid not null references public.series (id) on delete cascade,
  actor_id       uuid not null references public.actors (id) on delete cascade,
  character_name text,
  sort_order     int not null default 0,
  primary key (series_id, actor_id)
);

-- ---------------------------------------------------------------------
-- مصادر الفيديو والترجمات
-- روابط الفيديو محمية: لا يقرؤها أحد مباشرةً إلا المسؤول،
-- والمستخدم يحصل عليها عبر الدالة get_playback_sources بعد التحقق.
-- ---------------------------------------------------------------------
create table public.video_sources (
  id             uuid primary key default gen_random_uuid(),
  movie_id       uuid references public.movies (id) on delete cascade,
  episode_id     uuid references public.episodes (id) on delete cascade,
  label          text not null,
  quality_height int,
  url            text not null,
  type           text not null default 'mp4' check (type in ('mp4', 'hls', 'dash')),
  is_active      boolean not null default true,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),
  check (num_nonnulls(movie_id, episode_id) = 1)
);

create table public.subtitles (
  id         uuid primary key default gen_random_uuid(),
  movie_id   uuid references public.movies (id) on delete cascade,
  episode_id uuid references public.episodes (id) on delete cascade,
  language   text not null,
  label      text,
  url        text not null,
  format     text not null default 'srt' check (format in ('srt', 'vtt')),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  check (num_nonnulls(movie_id, episode_id) = 1)
);

-- ---------------------------------------------------------------------
-- بيانات المستخدم
-- ---------------------------------------------------------------------
create table public.favorites (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('movie', 'series')),
  movie_id   uuid references public.movies (id) on delete cascade,
  series_id  uuid references public.series (id) on delete cascade,
  title_id   uuid generated always as (coalesce(movie_id, series_id)) stored,
  created_at timestamptz not null default now(),
  unique (user_id, title_id),
  check (
    (kind = 'movie'  and movie_id  is not null and series_id is null) or
    (kind = 'series' and series_id is not null and movie_id  is null)
  )
);

create table public.watch_history (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  kind             text not null check (kind in ('movie', 'episode')),
  movie_id         uuid references public.movies (id) on delete cascade,
  series_id        uuid references public.series (id) on delete cascade,
  episode_id       uuid references public.episodes (id) on delete cascade,
  content_id       uuid generated always as (coalesce(movie_id, episode_id)) stored,
  position_seconds int not null default 0 check (position_seconds >= 0),
  duration_seconds int not null default 0 check (duration_seconds >= 0),
  completed        boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (user_id, content_id),
  check (
    (kind = 'movie'   and movie_id   is not null and episode_id is null and series_id is null) or
    (kind = 'episode' and episode_id is not null and series_id  is not null and movie_id is null)
  )
);

-- أحداث المشاهدة (للإحصائيات). الإدراج فقط عبر الدالة log_view.
create table public.view_events (
  id         bigint generated always as identity primary key,
  user_id    uuid references public.profiles (id) on delete set null,
  kind       text not null check (kind in ('movie', 'episode')),
  movie_id   uuid references public.movies (id) on delete cascade,
  series_id  uuid references public.series (id) on delete cascade,
  episode_id uuid references public.episodes (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- إعدادات التطبيق
-- ---------------------------------------------------------------------
create table public.app_settings (
  key         text primary key,
  value       jsonb not null default 'null'::jsonb,
  description text,
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- بنية الاشتراكات (جاهزة للمستقبل - لا يوجد مزوّد دفع مربوط)
-- ---------------------------------------------------------------------
create table public.subscription_plans (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  name_ar        text not null,
  name_en        text not null,
  billing_period text not null default 'none' check (billing_period in ('none', 'monthly', 'yearly')),
  price          numeric(10, 2) not null default 0,
  currency       text not null default 'USD',
  max_devices    int not null default 1,
  features       jsonb not null default '{}'::jsonb,
  is_active      boolean not null default true,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now()
);

create table public.subscriptions (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references public.profiles (id) on delete cascade,
  plan_id              uuid not null references public.subscription_plans (id),
  status               text not null default 'active'
                       check (status in ('active', 'trialing', 'past_due', 'canceled', 'expired')),
  provider             text,
  provider_ref         text,
  current_period_start timestamptz,
  current_period_end   timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at           timestamptz not null default now()
);

create table public.payments (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  subscription_id uuid references public.subscriptions (id) on delete set null,
  amount          numeric(10, 2) not null,
  currency        text not null default 'USD',
  provider        text not null,
  provider_ref    text,
  status          text not null default 'pending'
                  check (status in ('pending', 'succeeded', 'failed', 'refunded')),
  created_at      timestamptz not null default now()
);

create table public.user_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  device_id    text not null,
  device_name  text,
  platform     text,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (user_id, device_id)
);

-- ---------------------------------------------------------------------
-- الفهارس
-- ---------------------------------------------------------------------
create index movies_published_created_idx on public.movies (is_published, created_at desc);
create index movies_views_idx             on public.movies (view_count desc);
create index movies_featured_idx          on public.movies (is_featured, featured_order);
create index movies_origin_idx            on public.movies (origin);
create index movies_year_idx              on public.movies (release_year);
create index movies_title_ar_trgm         on public.movies using gin (public.ar_norm(title_ar) gin_trgm_ops);
create index movies_title_en_trgm         on public.movies using gin (lower(coalesce(title_en, '')) gin_trgm_ops);

create index series_published_created_idx on public.series (is_published, created_at desc);
create index series_views_idx             on public.series (view_count desc);
create index series_featured_idx          on public.series (is_featured, featured_order);
create index series_origin_idx            on public.series (origin);
create index series_year_idx              on public.series (release_year);
create index series_title_ar_trgm         on public.series using gin (public.ar_norm(title_ar) gin_trgm_ops);
create index series_title_en_trgm         on public.series using gin (lower(coalesce(title_en, '')) gin_trgm_ops);

create index actors_name_ar_trgm on public.actors using gin (public.ar_norm(name_ar) gin_trgm_ops);
create index actors_name_en_trgm on public.actors using gin (lower(coalesce(name_en, '')) gin_trgm_ops);

create index seasons_series_idx   on public.seasons (series_id);
create index episodes_season_idx  on public.episodes (season_id);
create index episodes_series_idx  on public.episodes (series_id);

create index movie_genres_genre_idx  on public.movie_genres (genre_id);
create index series_genres_genre_idx on public.series_genres (genre_id);
create index movie_actors_actor_idx  on public.movie_actors (actor_id);
create index series_actors_actor_idx on public.series_actors (actor_id);

create index video_sources_movie_idx   on public.video_sources (movie_id);
create index video_sources_episode_idx on public.video_sources (episode_id);
create index subtitles_movie_idx       on public.subtitles (movie_id);
create index subtitles_episode_idx     on public.subtitles (episode_id);

create index favorites_user_idx      on public.favorites (user_id, created_at desc);
create index watch_history_user_idx  on public.watch_history (user_id, updated_at desc);
create index view_events_created_idx on public.view_events (created_at desc);
create index view_events_user_idx    on public.view_events (user_id, kind, created_at desc);
create index subscriptions_user_idx  on public.subscriptions (user_id);
create index payments_user_idx       on public.payments (user_id);
create index categories_sort_idx     on public.categories (sort_order);

-- ---------------------------------------------------------------------
-- المشغّلات
-- ---------------------------------------------------------------------
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger movies_updated_at before update on public.movies
  for each row execute function public.set_updated_at();
create trigger series_updated_at before update on public.series
  for each row execute function public.set_updated_at();
create trigger episodes_updated_at before update on public.episodes
  for each row execute function public.set_updated_at();
create trigger app_settings_updated_at before update on public.app_settings
  for each row execute function public.set_updated_at();

-- ملء series_id للحلقة من الموسم تلقائياً
create or replace function public.episodes_fill_series()
returns trigger language plpgsql set search_path = '' as $$
begin
  select s.series_id into new.series_id from public.seasons s where s.id = new.season_id;
  return new;
end $$;

create trigger episodes_fill_series before insert or update of season_id on public.episodes
  for each row execute function public.episodes_fill_series();

-- منع المستخدم العادي من تغيير الدور أو الحظر أو البريد في ملفه
-- (auth.uid() يكون null عند التنفيذ من SQL Editor أو بمفتاح الخدمة فيُسمح)
create or replace function public.protect_profile_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.role       := old.role;
    new.is_blocked := old.is_blocked;
    new.email      := old.email;
  end if;
  return new;
end $$;

create trigger profiles_protect before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- إنشاء ملف المستخدم تلقائياً عند التسجيل (الدور دائماً user)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- العرض الموحّد للأفلام والمسلسلات (يحترم RLS الخاص بالمستخدم المستدعي)
-- ---------------------------------------------------------------------
create or replace view public.catalog with (security_invoker = true) as
  select m.id, 'movie'::text as kind, m.title_ar, m.title_en, m.overview_ar, m.overview_en,
         m.poster_url, m.backdrop_url, m.release_year, m.age_rating, m.country, m.language,
         m.origin, m.quality, m.rating, m.runtime_minutes, m.director,
         m.is_featured, m.featured_order, m.is_premium, m.view_count, m.created_at
  from public.movies m
  where m.is_published
  union all
  select s.id, 'series'::text, s.title_ar, s.title_en, s.overview_ar, s.overview_en,
         s.poster_url, s.backdrop_url, s.release_year, s.age_rating, s.country, s.language,
         s.origin, s.quality, s.rating, s.runtime_minutes, s.director,
         s.is_featured, s.featured_order, s.is_premium, s.view_count, s.created_at
  from public.series s
  where s.is_published;

-- >>>>>>>>>> 02_functions.sql
-- =====================================================================
-- CINEMA X — 02_functions.sql
-- دوال RPC التي يستدعيها التطبيق. كل التحقق من الصلاحيات يتم هنا على الخادم.
-- =====================================================================

set search_path = public, extensions;

-- ---------------------------------------------------------------------
-- اشتراك Premium فعّال؟
-- ---------------------------------------------------------------------
create or replace function public.has_active_premium()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.subscriptions s
    join public.subscription_plans p on p.id = s.plan_id
    where s.user_id = auth.uid()
      and s.status in ('active', 'trialing')
      and (s.current_period_end is null or s.current_period_end > now())
      and p.code <> 'free'
  );
$$;

-- الخطة الحالية للمستخدم (الافتراضية: free)
create or replace function public.current_plan()
returns public.subscription_plans language sql stable security definer set search_path = public as $$
  select p.*
  from public.subscription_plans p
  where p.id = coalesce(
    (select s.plan_id
       from public.subscriptions s
      where s.user_id = auth.uid()
        and s.status in ('active', 'trialing')
        and (s.current_period_end is null or s.current_period_end > now())
      order by s.created_at desc
      limit 1),
    (select f.id from public.subscription_plans f where f.code = 'free' limit 1)
  );
$$;

-- ---------------------------------------------------------------------
-- روابط التشغيل (محمية): تتطلب تسجيل دخول + حساب غير محظور + اشتراك إن كان المحتوى مدفوعاً
-- ---------------------------------------------------------------------
create or replace function public.get_playback_sources(
  p_movie_id uuid default null,
  p_episode_id uuid default null
)
returns table (id uuid, label text, quality_height int, url text, type text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_premium boolean := false;
  v_enabled boolean := false;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  if exists (select 1 from public.profiles pr where pr.id = auth.uid() and pr.is_blocked) then
    raise exception 'account_blocked' using errcode = '42501';
  end if;

  if (p_movie_id is null) = (p_episode_id is null) then
    raise exception 'invalid_arguments' using errcode = '22023';
  end if;

  if p_movie_id is not null then
    select m.is_premium into v_premium
      from public.movies m
     where m.id = p_movie_id and (m.is_published or public.is_admin());
  else
    select s.is_premium into v_premium
      from public.episodes e
      join public.series s on s.id = e.series_id
     where e.id = p_episode_id
       and ((e.is_published and s.is_published) or public.is_admin());
  end if;

  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  select coalesce((a.value #>> '{}') = 'true', false) into v_enabled
    from public.app_settings a
   where a.key = 'subscriptions_enabled';

  if coalesce(v_premium, false)
     and coalesce(v_enabled, false)
     and not public.has_active_premium()
     and not public.is_admin() then
    raise exception 'premium_required' using errcode = '42501';
  end if;

  return query
    select vs.id, vs.label, vs.quality_height, vs.url, vs.type
      from public.video_sources vs
     where vs.is_active
       and ((p_movie_id is not null and vs.movie_id = p_movie_id)
         or (p_episode_id is not null and vs.episode_id = p_episode_id))
     order by vs.sort_order, vs.quality_height desc nulls last;
end $$;

-- ---------------------------------------------------------------------
-- البحث والتصفح (اسم عربي/إنجليزي، ممثل، مخرج، سنة، نوع، دولة)
-- ---------------------------------------------------------------------
create or replace function public.browse_catalog(
  p_query    text default null,
  p_kind     text default null,
  p_origin   text default null,
  p_genre_id uuid default null,
  p_year     int  default null,
  p_country  text default null,
  p_sort     text default 'latest',
  p_limit    int  default 24,
  p_offset   int  default 0
)
returns setof public.catalog
language plpgsql stable security invoker set search_path = public, extensions as $$
declare
  v_raw text := nullif(btrim(coalesce(p_query, '')), '');
  v_ar  text;
  v_en  text;
begin
  if v_raw is not null then
    v_raw := replace(replace(replace(v_raw, '\', '\\'), '%', '\%'), '_', '\_');
    v_ar  := '%' || public.ar_norm(v_raw) || '%';
    v_en  := '%' || lower(v_raw) || '%';
  end if;

  return query
  select c.*
    from public.catalog c
   where (p_kind is null or c.kind = p_kind)
     and (p_origin is null or c.origin = p_origin)
     and (p_year is null or c.release_year = p_year)
     and (p_country is null or c.country = p_country)
     and (p_genre_id is null
          or (c.kind = 'movie' and exists (
                select 1 from public.movie_genres mg
                 where mg.movie_id = c.id and mg.genre_id = p_genre_id))
          or (c.kind = 'series' and exists (
                select 1 from public.series_genres sg
                 where sg.series_id = c.id and sg.genre_id = p_genre_id)))
     and (v_raw is null
          or public.ar_norm(c.title_ar) like v_ar
          or lower(coalesce(c.title_en, '')) like v_en
          or lower(coalesce(c.director, '')) like v_en
          or (c.kind = 'movie' and exists (
                select 1 from public.movie_actors ma
                  join public.actors a on a.id = ma.actor_id
                 where ma.movie_id = c.id
                   and (public.ar_norm(a.name_ar) like v_ar or lower(coalesce(a.name_en, '')) like v_en)))
          or (c.kind = 'series' and exists (
                select 1 from public.series_actors sa
                  join public.actors a on a.id = sa.actor_id
                 where sa.series_id = c.id
                   and (public.ar_norm(a.name_ar) like v_ar or lower(coalesce(a.name_en, '')) like v_en))))
   order by
     case when p_sort = 'popular' then c.view_count end desc nulls last,
     case when p_sort = 'rating'  then c.rating end desc nulls last,
     case when p_sort = 'year'    then c.release_year end desc nulls last,
     c.created_at desc
   limit least(greatest(coalesce(p_limit, 24), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
end $$;

-- اقتراحات أثناء الكتابة
create or replace function public.search_suggestions(p_query text)
returns table (suggestion text, kind text)
language plpgsql stable security invoker set search_path = public, extensions as $$
declare
  v_raw text := nullif(btrim(coalesce(p_query, '')), '');
  v_ar  text;
  v_en  text;
begin
  if v_raw is null then
    return;
  end if;
  v_raw := replace(replace(replace(v_raw, '\', '\\'), '%', '\%'), '_', '\_');
  v_ar  := '%' || public.ar_norm(v_raw) || '%';
  v_en  := '%' || lower(v_raw) || '%';

  return query
  select x.s, x.k
    from (
      (select t.s, 'title'::text as k
         from (
           select c.title_ar as s, c.view_count as vc
             from public.catalog c
            where public.ar_norm(c.title_ar) like v_ar
           union all
           select c.title_en, c.view_count
             from public.catalog c
            where c.title_en is not null and lower(c.title_en) like v_en
         ) t
        order by t.vc desc
        limit 6)
      union all
      (select a.name_ar as s, 'actor'::text as k
         from public.actors a
        where public.ar_norm(a.name_ar) like v_ar or lower(coalesce(a.name_en, '')) like v_en
        limit 4)
    ) x;
end $$;

create or replace function public.catalog_countries()
returns table (country text)
language sql stable security invoker set search_path = public as $$
  select distinct c.country
    from public.catalog c
   where c.country is not null and c.country <> ''
   order by 1;
$$;

-- ---------------------------------------------------------------------
-- حفظ موضع المشاهدة (يُحتسب الإكمال على الخادم)
-- ---------------------------------------------------------------------
create or replace function public.save_progress(
  p_kind       text,
  p_movie_id   uuid,
  p_series_id  uuid,
  p_episode_id uuid,
  p_position   int,
  p_duration   int
)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_completed boolean;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_kind not in ('movie', 'episode') then
    raise exception 'invalid_kind' using errcode = '22023';
  end if;

  v_completed := p_duration > 0 and (p_position >= p_duration * 0.95 or p_duration - p_position < 45);

  insert into public.watch_history
    (user_id, kind, movie_id, series_id, episode_id, position_seconds, duration_seconds, completed, updated_at)
  values (
    auth.uid(),
    p_kind,
    case when p_kind = 'movie' then p_movie_id end,
    case when p_kind = 'episode' then p_series_id end,
    case when p_kind = 'episode' then p_episode_id end,
    greatest(p_position, 0),
    greatest(p_duration, 0),
    v_completed,
    now()
  )
  on conflict (user_id, content_id) do update
    set position_seconds = excluded.position_seconds,
        duration_seconds = excluded.duration_seconds,
        completed        = excluded.completed,
        updated_at       = now();
end $$;

-- ---------------------------------------------------------------------
-- تسجيل مشاهدة (حدث واحد لكل مستخدم/محتوى كل 30 دقيقة لتقليل التلاعب)
-- ---------------------------------------------------------------------
create or replace function public.log_view(
  p_kind       text,
  p_movie_id   uuid default null,
  p_series_id  uuid default null,
  p_episode_id uuid default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or p_kind not in ('movie', 'episode') then
    return;
  end if;

  if exists (
    select 1 from public.view_events v
     where v.user_id = auth.uid()
       and v.kind = p_kind
       and v.movie_id is not distinct from p_movie_id
       and v.episode_id is not distinct from p_episode_id
       and v.created_at > now() - interval '30 minutes'
  ) then
    return;
  end if;

  insert into public.view_events (user_id, kind, movie_id, series_id, episode_id)
  values (auth.uid(), p_kind, p_movie_id, p_series_id, p_episode_id);

  if p_kind = 'movie' then
    update public.movies set view_count = view_count + 1 where id = p_movie_id;
  else
    update public.episodes set view_count = view_count + 1 where id = p_episode_id;
    update public.series   set view_count = view_count + 1 where id = p_series_id;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- إحصائيات الإدارة (للمسؤول فقط)
-- ---------------------------------------------------------------------
create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'users',        (select count(*) from public.profiles),
    'new_users_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'movies',       (select count(*) from public.movies),
    'series',       (select count(*) from public.series),
    'episodes',     (select count(*) from public.episodes),
    'views_total',  (select count(*) from public.view_events),
    'views_7d',     (select count(*) from public.view_events where created_at > now() - interval '7 days'),
    'views_by_day', (
      select coalesce(jsonb_agg(jsonb_build_object('day', d.day, 'views', coalesce(v.c, 0)) order by d.day), '[]'::jsonb)
        from (select generate_series(current_date - 6, current_date, interval '1 day')::date as day) d
        left join (
          select (created_at at time zone 'UTC')::date as day, count(*) as c
            from public.view_events
           where created_at > now() - interval '8 days'
           group by 1
        ) v on v.day = d.day
    ),
    'top_titles', (
      select coalesce(jsonb_agg(t), '[]'::jsonb)
        from (select c.kind, c.id, c.title_ar, c.title_en, c.view_count
                from public.catalog c
               order by c.view_count desc
               limit 10) t
    )
  ) into result;

  return result;
end $$;

-- ---------------------------------------------------------------------
-- تسجيل الجهاز (حدود الأجهزة تُطبَّق فقط عند تفعيل subscriptions_enabled)
-- ---------------------------------------------------------------------
create or replace function public.register_device(
  p_device_id text,
  p_name      text default null,
  p_platform  text default null
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_enabled boolean := false;
  v_max     int;
  v_count   int;
begin
  if auth.uid() is null or coalesce(p_device_id, '') = '' then
    return;
  end if;

  insert into public.user_devices (user_id, device_id, device_name, platform, last_seen_at)
  values (auth.uid(), p_device_id, p_name, p_platform, now())
  on conflict (user_id, device_id) do update
    set last_seen_at = now(),
        device_name  = coalesce(excluded.device_name, public.user_devices.device_name);

  select coalesce((a.value #>> '{}') = 'true', false) into v_enabled
    from public.app_settings a
   where a.key = 'subscriptions_enabled';

  if coalesce(v_enabled, false) then
    select cp.max_devices into v_max from public.current_plan() cp;
    select count(*) into v_count from public.user_devices d where d.user_id = auth.uid();
    if v_max is not null and v_count > v_max then
      raise exception 'device_limit_reached' using errcode = '42501';
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- الصلاحيات: منع الزائر (anon) من استدعاء الدوال الحساسة
-- ---------------------------------------------------------------------
revoke all on function public.get_playback_sources(uuid, uuid) from public, anon;
revoke all on function public.browse_catalog(text, text, text, uuid, int, text, text, int, int) from public, anon;
revoke all on function public.search_suggestions(text) from public, anon;
revoke all on function public.catalog_countries() from public, anon;
revoke all on function public.save_progress(text, uuid, uuid, uuid, int, int) from public, anon;
revoke all on function public.log_view(text, uuid, uuid, uuid) from public, anon;
revoke all on function public.admin_stats() from public, anon;
revoke all on function public.register_device(text, text, text) from public, anon;
revoke all on function public.current_plan() from public, anon;
revoke all on function public.has_active_premium() from public, anon;

grant execute on function public.get_playback_sources(uuid, uuid) to authenticated;
grant execute on function public.browse_catalog(text, text, text, uuid, int, text, text, int, int) to authenticated;
grant execute on function public.search_suggestions(text) to authenticated;
grant execute on function public.catalog_countries() to authenticated;
grant execute on function public.save_progress(text, uuid, uuid, uuid, int, int) to authenticated;
grant execute on function public.log_view(text, uuid, uuid, uuid) to authenticated;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.register_device(text, text, text) to authenticated;
grant execute on function public.current_plan() to authenticated;
grant execute on function public.has_active_premium() to authenticated;

-- ---------------------------------------------------------------------
-- تقوية الأمان: دوال داخلية لا يجب أن تُستدعى مباشرةً عبر واجهة REST.
--  - is_admin(): تُستخدم داخل سياسات RLS للمستخدمين المسجّلين فقط.
--  - handle_new_user / protect_profile_fields: دوال مشغّلات (Triggers) فقط؛
--    صلاحية التنفيذ لا تُفحص وقت تشغيل المشغّل فلا يتأثر عملها.
-- ---------------------------------------------------------------------
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.protect_profile_fields() from public, anon, authenticated;

-- >>>>>>>>>> 03_rls.sql
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

-- >>>>>>>>>> 04_storage.sql
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

-- >>>>>>>>>> 05_seed.sql
-- =====================================================================
-- CINEMA X — 05_seed.sql
-- بيانات أولية: الأنواع، فئات الصفحة الرئيسية، خطط الاشتراك (هيكل فقط)، الإعدادات.
-- آمن للتشغيل أكثر من مرة.
-- =====================================================================

insert into public.genres (slug, name_ar, name_en, sort_order) values
  ('action',      'أكشن',        'Action',      10),
  ('horror',      'رعب',         'Horror',      20),
  ('sci-fi',      'خيال علمي',   'Sci-Fi',      30),
  ('comedy',      'كوميديا',     'Comedy',      40),
  ('drama',       'دراما',       'Drama',       50),
  ('romance',     'رومانسي',     'Romance',     60),
  ('thriller',    'إثارة',       'Thriller',    70),
  ('animation',   'رسوم متحركة', 'Animation',   80),
  ('anime',       'أنمي',        'Anime',       90),
  ('documentary', 'وثائقي',      'Documentary', 100),
  ('family',      'عائلي',       'Family',      110)
on conflict (slug) do nothing;

-- صفوف الصفحة الرئيسية (الأكثر مشاهدة/أحدث الإضافات تُحسب تلقائياً في التطبيق)
insert into public.categories (slug, name_ar, name_en, kind, origin, genre_id, layout, sort_order)
select v.slug, v.name_ar, v.name_en, v.kind, v.origin,
       (select g.id from public.genres g where g.slug = v.genre_slug),
       'poster', v.sort_order
from (values
  ('action-movies',    'أفلام الأكشن',       'Action Movies',     'movie',  null,      'action', 10),
  ('horror-movies',    'أفلام الرعب',        'Horror Movies',     'movie',  null,      'horror', 20),
  ('scifi-movies',     'أفلام الخيال العلمي','Sci-Fi Movies',     'movie',  null,      'sci-fi', 30),
  ('comedy-movies',    'أفلام الكوميديا',    'Comedy Movies',     'movie',  null,      'comedy', 40),
  ('arabic-movies',    'الأفلام العربية',    'Arabic Movies',     'movie',  'arab',    null,     50),
  ('foreign-movies',   'الأفلام الأجنبية',   'Foreign Movies',    'movie',  'foreign', null,     60),
  ('arabic-series',    'المسلسلات العربية',  'Arabic Series',     'series', 'arab',    null,     70),
  ('foreign-series',   'المسلسلات الأجنبية', 'Foreign Series',    'series', 'foreign', null,     80),
  ('anime',            'الأنمي',             'Anime',             null,     null,      'anime',  90)
) as v(slug, name_ar, name_en, kind, origin, genre_slug, sort_order)
on conflict (slug) do nothing;

-- خطط الاشتراك: هيكل جاهز فقط. لا يوجد مزوّد دفع مربوط، ولا يتم تحصيل أي مبلغ.
insert into public.subscription_plans (code, name_ar, name_en, billing_period, price, currency, max_devices, sort_order) values
  ('free',            'مجاني',         'Free',            'none',    0,     'USD', 1, 10),
  ('premium_monthly', 'بريميوم شهري',  'Premium Monthly', 'monthly', 4.99,  'USD', 4, 20),
  ('premium_yearly',  'بريميوم سنوي',  'Premium Yearly',  'yearly',  49.99, 'USD', 4, 30)
on conflict (code) do nothing;

insert into public.app_settings (key, value, description) values
  ('maintenance_mode',      'false'::jsonb, 'تفعيل وضع الصيانة (يُمنع غير المسؤولين من الدخول)'),
  ('maintenance_message',   '""'::jsonb,    'رسالة الصيانة'),
  ('subscriptions_enabled', 'false'::jsonb, 'تفعيل فحص الاشتراك للمحتوى المدفوع (اتركه false حتى تربط مزود دفع حقيقي)'),
  ('support_email',         '""'::jsonb,    'بريد الدعم')
on conflict (key) do nothing;

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

-- =====================================================================
-- بعد إنشاء أول حساب من التطبيق، اجعله مسؤولاً بتشغيل (غيّر البريد):
--
--   update public.profiles set role = 'admin' where email = 'you@example.com';
--
-- =====================================================================
