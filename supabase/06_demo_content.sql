-- =====================================================================
-- CINEMA X — 06_demo_content.sql   (اختياري - للاختبار فقط)
-- أفلام Blender القصيرة المفتوحة (Creative Commons Attribution)
-- مؤسسة Blender: Big Buck Bunny / Elephants Dream / Sintel / Tears of Steel
--
-- الروابط تابعة لجهات خارجية ولم أتمكن من التحقق من توفرها وقت الكتابة.
-- إن لم تعمل، عدّلها من لوحة الإدارة بروابط تملك حق عرضها.
-- لا تشغّل هذا الملف في بيئة الإنتاج.
-- =====================================================================

do $$
declare
  v_mp4_base constant text := 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/';
  v_hls      constant text := 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  m1 uuid; m2 uuid; m3 uuid; m4 uuid; s1 uuid; se1 uuid;
  e1 uuid; e2 uuid; e3 uuid;
begin
  if exists (select 1 from public.movies where title_en = 'Big Buck Bunny') then
    raise notice 'المحتوى التجريبي موجود مسبقاً - تم التخطي';
    return;
  end if;

  insert into public.movies (title_ar, title_en, overview_ar, overview_en, release_year, country, language, origin,
                             quality, runtime_minutes, director, age_rating, subtitle_languages, is_featured, featured_order)
  values ('بيغ باك باني', 'Big Buck Bunny',
          'فيلم رسوم متحركة قصير من إنتاج مؤسسة Blender عن أرنب ضخم طيّب القلب يواجه ثلاثة قوارض مشاكسة.',
          'A short open-source animated film by the Blender Foundation about a giant, kind-hearted rabbit and three mischievous rodents.',
          2008, 'Netherlands', 'en', 'foreign', 'HD', 10, 'Sacha Goedegebure', 'G', '{}', true, 1)
  returning id into m1;

  insert into public.movies (title_ar, title_en, overview_ar, overview_en, release_year, country, language, origin,
                             quality, runtime_minutes, director, age_rating, subtitle_languages, is_featured, featured_order)
  values ('حلم الفيلة', 'Elephants Dream',
          'أول فيلم قصير مفتوح المصدر من Blender، يتابع شخصيتين داخل آلة سريالية غريبة.',
          'The first open-source short film from Blender, following two characters inside a strange, surreal machine.',
          2006, 'Netherlands', 'en', 'foreign', 'HD', 11, 'Bassam Kurdali', 'PG', '{}', true, 2)
  returning id into m2;

  insert into public.movies (title_ar, title_en, overview_ar, overview_en, release_year, country, language, origin,
                             quality, runtime_minutes, director, age_rating, subtitle_languages, is_featured, featured_order)
  values ('سينتل', 'Sintel',
          'فيلم فانتازيا قصير عن فتاة تدعى سينتل تبحث عن تنين صغير صادقته.',
          'A short fantasy film about a girl named Sintel who searches for a baby dragon she befriended.',
          2010, 'Netherlands', 'en', 'foreign', 'HD', 15, 'Colin Levy', 'PG-13', '{en}', true, 3)
  returning id into m3;

  insert into public.movies (title_ar, title_en, overview_ar, overview_en, release_year, country, language, origin,
                             quality, runtime_minutes, director, age_rating, subtitle_languages, is_featured, featured_order)
  values ('دموع الفولاذ', 'Tears of Steel',
          'فيلم خيال علمي قصير تدور أحداثه في أمستردام مستقبلية، يجمع بين التصوير الحي والمؤثرات البصرية.',
          'A short sci-fi film set in a future Amsterdam, combining live-action footage and visual effects.',
          2012, 'Netherlands', 'en', 'foreign', 'HD', 12, 'Ian Hubert', 'PG-13', '{}', true, 4)
  returning id into m4;

  insert into public.video_sources (movie_id, label, quality_height, url, type, sort_order) values
    (m1, '720p',        720,  v_mp4_base || 'BigBuckBunny.mp4',    'mp4', 1),
    (m1, 'Auto (HLS)',  null, v_hls,                               'hls', 0),
    (m2, '720p',        720,  v_mp4_base || 'ElephantsDream.mp4',  'mp4', 1),
    (m3, '720p',        720,  v_mp4_base || 'Sintel.mp4',          'mp4', 1),
    (m4, '720p',        720,  v_mp4_base || 'TearsOfSteel.mp4',    'mp4', 1);

  insert into public.subtitles (movie_id, language, label, url, format, is_default)
  values (m3, 'en', 'English', 'https://durian.blender.org/wp-content/content/subtitles/sintel_en.srt', 'srt', false);

  insert into public.movie_genres (movie_id, genre_id)
  select m1, g.id from public.genres g where g.slug in ('animation', 'comedy', 'family')
  union all select m2, g.id from public.genres g where g.slug in ('animation', 'sci-fi')
  union all select m3, g.id from public.genres g where g.slug in ('animation', 'action')
  union all select m4, g.id from public.genres g where g.slug in ('sci-fi', 'action');

  -- مسلسل تجريبي يعيد استخدام المقاطع أعلاه كحلقات
  insert into public.series (title_ar, title_en, overview_ar, overview_en, release_year, country, language, origin,
                             quality, runtime_minutes, age_rating, is_featured, featured_order)
  values ('سلسلة عرض تجريبي', 'Demo Series',
          'مسلسل تجريبي لاختبار المواسم والحلقات والتشغيل التلقائي للحلقة التالية. الحلقات مقاطع Blender.',
          'A demo series for testing seasons, episodes and next-episode autoplay. Episodes reuse Blender shorts.',
          2024, 'Netherlands', 'en', 'foreign', 'HD', 12, 'PG', false, 0)
  returning id into s1;

  insert into public.series_genres (series_id, genre_id)
  select s1, g.id from public.genres g where g.slug in ('animation', 'family');

  insert into public.seasons (series_id, season_number, title_ar, title_en)
  values (s1, 1, 'الموسم الأول', 'Season 1')
  returning id into se1;

  insert into public.episodes (season_id, episode_number, title_ar, title_en, runtime_minutes)
  values (se1, 1, 'الحلقة الأولى', 'Episode 1', 10) returning id into e1;
  insert into public.episodes (season_id, episode_number, title_ar, title_en, runtime_minutes)
  values (se1, 2, 'الحلقة الثانية', 'Episode 2', 11) returning id into e2;
  insert into public.episodes (season_id, episode_number, title_ar, title_en, runtime_minutes)
  values (se1, 3, 'الحلقة الثالثة', 'Episode 3', 15) returning id into e3;

  insert into public.video_sources (episode_id, label, quality_height, url, type, sort_order) values
    (e1, '720p', 720, v_mp4_base || 'BigBuckBunny.mp4',   'mp4', 1),
    (e2, '720p', 720, v_mp4_base || 'ElephantsDream.mp4', 'mp4', 1),
    (e3, '720p', 720, v_mp4_base || 'Sintel.mp4',         'mp4', 1);
end $$;
