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
