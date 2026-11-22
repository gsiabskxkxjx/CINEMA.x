-- اختبار دخاني لقاعدة CINEMA X: الصلاحيات (RLS) + الدوال + البحث العربي.
-- يُشغَّل بعد 01..06 على قاعدة فيها stub_supabase.sql. أي فشل يوقف التنفيذ.
\set ON_ERROR_STOP on

do $$
declare
  u1  uuid := '11111111-1111-1111-1111-111111111111';
  adm uuid := '22222222-2222-2222-2222-222222222222';
  n int; v_m uuid; v_s uuid; v_e uuid; v_actor uuid; v_genre uuid; v_json jsonb; v_ok boolean;
begin
  -- 1) إنشاء الحسابات => ملفات profiles تلقائياً بدور user
  insert into auth.users (id, email, raw_user_meta_data) values
    (u1,  'user@test.dev',  '{"display_name":"مستخدم"}'),
    (adm, 'admin@test.dev', '{}');
  select count(*) into n from public.profiles;
  assert n = 2, 'مشغّل handle_new_user لم ينشئ الملفات';
  assert (select display_name from public.profiles where id = u1) = 'مستخدم', 'display_name';
  assert (select role from public.profiles where id = adm) = 'user', 'الدور الافتراضي يجب أن يكون user';
  update public.profiles set role = 'admin' where id = adm;  -- من SQL Editor (بدون auth.uid) مسموح

  -- 2) المستخدم لا يستطيع ترقية نفسه
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  update public.profiles set role = 'admin', is_blocked = false, display_name = 'Edited' where id = u1;
  reset role;
  assert (select role from public.profiles where id = u1) = 'user', 'ثغرة: المستخدم رقّى نفسه إلى admin';
  assert (select display_name from public.profiles where id = u1) = 'Edited', 'تعديل الاسم يجب أن ينجح';

  -- 3) محتوى تجريبي موجود (من 06)
  select count(*) into n from public.movies;       assert n = 4, 'عدد الأفلام التجريبية';
  select count(*) into n from public.episodes;     assert n = 3, 'عدد الحلقات';
  assert (select count(*) from public.episodes where series_id is null) = 0, 'series_id يجب أن يُملأ تلقائياً';

  select id into v_m from public.movies where title_en = 'Sintel';
  select id into v_s from public.series limit 1;
  select e.id into v_e from public.episodes e order by episode_number limit 1;
  select id into v_genre from public.genres where slug = 'animation';
  insert into public.actors (name_ar, name_en) values ('أحمد زكي', 'Ahmed Zaki') returning id into v_actor;
  insert into public.movie_actors (movie_id, actor_id, character_name) values (v_m, v_actor, 'Sintel');

  -- 4) المستخدم العادي: لا يرى روابط الفيديو مباشرةً ولا يكتب محتوى
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  select count(*) into n from public.video_sources;
  assert n = 0, 'ثغرة: المستخدم يقرأ video_sources مباشرةً';

  v_ok := false;
  begin
    insert into public.movies (title_ar) values ('اختراق');
  exception when insufficient_privilege then v_ok := true;
  end;
  assert v_ok, 'ثغرة: المستخدم أضاف فيلماً';

  v_ok := false;
  begin
    update public.app_settings set value = 'true'::jsonb where key = 'maintenance_mode';
    get diagnostics n = row_count;
    v_ok := (n = 0);
  exception when insufficient_privilege then v_ok := true;
  end;
  assert v_ok, 'ثغرة: المستخدم عدّل app_settings';

  -- 5) لكن يحصل على الروابط عبر الدالة المحمية
  select count(*) into n from public.get_playback_sources(p_movie_id => v_m);
  assert n = 1, 'get_playback_sources للفيلم';
  select count(*) into n from public.get_playback_sources(p_episode_id => v_e);
  assert n = 1, 'get_playback_sources للحلقة';
  reset role;

  -- 6) الزائر المجهول لا يستدعي الدوال الحساسة ولا يقرأ المحتوى
  set local role anon;
  v_ok := false;
  begin
    perform * from public.get_playback_sources(p_movie_id => v_m);
  exception when insufficient_privilege then v_ok := true;
  end;
  assert v_ok, 'ثغرة: anon استدعى get_playback_sources';
  select count(*) into n from public.movies;
  assert n = 0, 'ثغرة: anon يقرأ movies';
  select count(*) into n from public.app_settings;
  assert n >= 3, 'app_settings يجب أن تكون مقروءة للجميع';
  reset role;

  -- 7) المسؤول يرى كل شيء ويدير
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', adm::text, true);
  select count(*) into n from public.video_sources;
  assert n >= 8, 'المسؤول يجب أن يقرأ video_sources';
  insert into public.movies (title_ar, title_en, is_published) values ('مسودة', 'Draft', false);
  assert (select count(*) from public.movies where title_en = 'Draft') = 1, 'المسؤول يرى المسودات';
  v_json := public.admin_stats();
  assert (v_json ->> 'movies')::int = 5 and (v_json ->> 'users')::int = 2, 'admin_stats';
  assert jsonb_array_length(v_json -> 'views_by_day') = 7, 'views_by_day = 7 أيام';
  reset role;

  -- 8) المستخدم لا يقرأ المسودات ولا admin_stats
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  assert (select count(*) from public.movies where title_en = 'Draft') = 0, 'ثغرة: المستخدم يرى المسودات';
  assert (select count(*) from public.catalog where title_en = 'Draft') = 0, 'catalog يجب ألا يعرض المسودات';
  v_ok := false;
  begin
    perform public.admin_stats();
  exception when insufficient_privilege then v_ok := true;
  end;
  assert v_ok, 'ثغرة: المستخدم استدعى admin_stats';

  -- 9) البحث
  select count(*) into n from public.browse_catalog(p_query => 'Sintel');
  assert n = 1, 'بحث إنجليزي';
  select count(*) into n from public.browse_catalog(p_query => 'سِينْتِل');       -- بتشكيل
  assert n = 1, 'بحث عربي مع تشكيل';
  select count(*) into n from public.browse_catalog(p_query => 'دموع');
  assert n = 1, 'بحث عربي جزئي';
  select count(*) into n from public.browse_catalog(p_query => 'colin');
  assert n = 1, 'بحث بالمخرج';
  select count(*) into n from public.browse_catalog(p_query => 'احمد زكي');        -- ألف بلا همزة
  assert n = 1, 'بحث بالممثل مع توحيد الألف';
  select count(*) into n from public.browse_catalog(p_kind => 'series');
  assert n = 1, 'فلتر المسلسلات';
  select count(*) into n from public.browse_catalog(p_genre_id => v_genre);
  assert n = 4, 'فلتر النوع (animation) = 3 أفلام + مسلسل';
  select count(*) into n from public.browse_catalog(p_year => 2010);
  assert n = 1, 'فلتر السنة';
  select count(*) into n from public.browse_catalog(p_query => '100%_x');           -- أحرف خاصة لا تكسر البحث
  assert n = 0, 'هروب أحرف LIKE';
  select count(*) into n from public.browse_catalog(p_limit => 2, p_offset => 3);
  assert n = 2, 'ترقيم الصفحات';
  select count(*) into n from public.search_suggestions('sin');
  assert n >= 1, 'اقتراحات';
  select count(*) into n from public.catalog_countries();
  assert n = 1, 'الدول';

  -- 10) التقدم والمشاهدات
  perform public.save_progress('movie', v_m, null, null, 100, 900);
  assert (select completed from public.watch_history where movie_id = v_m) = false, 'غير مكتمل';
  perform public.save_progress('movie', v_m, null, null, 880, 900);
  assert (select count(*) from public.watch_history where movie_id = v_m) = 1, 'upsert لا يكرر الصف';
  assert (select completed from public.watch_history where movie_id = v_m) = true, 'مكتمل بعد 95%';
  perform public.save_progress('episode', null, v_s, v_e, 30, 600);
  assert (select count(*) from public.watch_history where user_id = u1) = 2, 'سجل فيلم + حلقة';

  perform public.log_view('movie', v_m, null, null);
  perform public.log_view('movie', v_m, null, null);
  perform public.log_view('episode', null, v_s, v_e);
  reset role;
  assert (select view_count from public.movies where id = v_m) = 1, 'log_view يمنع التكرار خلال 30 دقيقة';
  assert (select view_count from public.series where id = v_s) = 1, 'عدّاد المسلسل';
  assert (select count(*) from public.view_events) = 2, 'أحداث المشاهدة';

  -- 11) المفضلة
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  insert into public.favorites (user_id, kind, movie_id) values (u1, 'movie', v_m)
    on conflict (user_id, title_id) do nothing;
  insert into public.favorites (user_id, kind, movie_id) values (u1, 'movie', v_m)
    on conflict (user_id, title_id) do nothing;
  assert (select count(*) from public.favorites) = 1, 'منع تكرار المفضلة';
  v_ok := false;
  begin
    insert into public.favorites (user_id, kind, movie_id) values (adm, 'movie', v_m);
  exception when insufficient_privilege then v_ok := true;
  end;
  assert v_ok, 'ثغرة: إضافة مفضلة باسم مستخدم آخر';

  -- 12) الأجهزة والخطة
  perform public.register_device('dev-1', 'Pixel', 'android');
  perform public.register_device('dev-1', 'Pixel', 'android');
  assert (select count(*) from public.user_devices) = 1, 'تسجيل الجهاز idempotent';
  assert (select code from public.current_plan()) = 'free', 'الخطة الافتراضية free';
  reset role;

  -- 13) المحتوى المدفوع عند تفعيل الاشتراكات
  update public.movies set is_premium = true where id = v_m;
  update public.app_settings set value = 'true'::jsonb where key = 'subscriptions_enabled';
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  v_ok := false;
  begin
    perform * from public.get_playback_sources(p_movie_id => v_m);
  exception when insufficient_privilege then v_ok := true;
  end;
  assert v_ok, 'premium_required يجب أن يمنع غير المشتركين';
  reset role;

  -- 14) الحظر
  perform set_config('request.jwt.claim.sub', '', true);   -- عودة إلى سياق SQL Editor (بلا مستخدم)
  update public.app_settings set value = 'false'::jsonb where key = 'subscriptions_enabled';
  update public.profiles set is_blocked = true where id = u1;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  v_ok := false;
  begin
    perform * from public.get_playback_sources(p_episode_id => v_e);
  exception when insufficient_privilege then v_ok := true;
  end;
  assert v_ok, 'المحظور يجب ألا يشغّل';
  reset role;

  -- 15) سياسات التخزين موجودة
  select count(*) into n from pg_policies where schemaname = 'storage' and tablename = 'objects';
  assert n = 7, 'سياسات storage: ' || n;

  raise notice '✓ كل اختبارات SQL نجحت';
end $$;
