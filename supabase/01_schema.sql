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
