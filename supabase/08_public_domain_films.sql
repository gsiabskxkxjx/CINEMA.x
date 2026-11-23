-- =====================================================================
-- CINEMA X — 08_public_domain_films.sql   (اختياري)
-- 28 فيلماً قديماً من أرشيف الإنترنت (archive.org)، مع روابط تشغيل MP4 مباشرة.
-- المصدر الذي اقتُرحت منه: https://github.com/OnlineM3U/publicdomainm3u (قائمة روابط فقط،
-- بلا ترخيص معلن ولا توثيق لوضع الملكية العامة).
--
-- ⚠️ ملكية عامة لا تعني «بلا قيود» في كل مكان:
--   * الوضع القانوني يختلف من دولة لأخرى. أرشيف الإنترنت نفسه لا يضمن حالة حقوق موادّه،
--     ووسم الترخيص على كل عنصر يضعه الرافع وليس الأرشيف.
--   * المجموعة (أ): أفلام صامتة قديمة جداً (شابلن قبل 1918، نوسفيراتو، شبح الأوبرا، بوتمكين):
--     أقوى موقف، وإن كان لنسخة محددة (ترميم/موسيقى) حقوقها أحياناً.
--   * المجموعة (ب): أفلام ملكية عامة في الولايات المتحدة (سقوط الحماية بعدم التجديد/غياب
--     الإشعار أو بانتهاء المدة) وقد تبقى محمية في دول أخرى. مناسبة للتجربة الشخصية؛
--     راجع الوضع في بلدك قبل أي نشر عام.
--   * مستبعدان عمداً من القائمة الأصلية لأن وضعهما مشكوك فيه: Popeye meets Sinbad (1936)
--     و The Beverly Hillbillies S01E01 (1962، مسلسل لشركة CBS/Paramount).
--   * الروابط تُحمَّل من خوادم الأرشيف: لا تُنشئ ضغطاً كبيراً عليها، وقد يتغيّر اسم الملف
--     أو يُحذف عنصر؛ إن توقف رابط عدّله من لوحة الإدارة.
--
-- آمن للتشغيل أكثر من مرة (لا يكرّر فيلماً موجوداً بنفس العنوان والسنة).
-- الصورة المصغّرة من archive.org/services/img (إطار من الفيديو)؛ يمكن استبدالها لاحقاً.
-- =====================================================================

with src(ident, title_ar, title_en, yr, mins, country, lang, director, genres, url) as (
 values
 -- المجموعة (أ)
 ('nosferatu-1922_202504','نوسفيراتو','Nosferatu',1922,79,'Germany','de','F. W. Murnau',array['horror'],'https://archive.org/download/nosferatu-1922_202504/Nosferatu%20%281922%29.mp4'),
 ('ThePhantomoftheOpera','شبح الأوبرا','The Phantom of the Opera',1925,106,'United States of America','en','Rupert Julian',array['horror'],'https://archive.org/download/ThePhantomoftheOpera/Phantom_of_the_Opera_512kb.mp4'),
 ('BattleshipPotemkin','المدرعة بوتمكين','Battleship Potemkin',1925,73,'Soviet Union','ru','Sergei Eisenstein',array['drama'],'https://archive.org/download/BattleshipPotemkin/Battleship_Potemkin_512kb.mp4'),
 ('CC_1916_07_10_TheVagabond','شارلي شابلن: المتشرد','The Vagabond',1916,25,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1916_07_10_TheVagabond/CC_1916_07_10_TheVagabond.mp4'),
 ('CC_1916_10_02_ThePawnshop','شارلي شابلن: محل الرهونات','The Pawnshop',1916,20,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1916_10_02_ThePawnshop/CC_1916_10_02_ThePawnshop_512kb.mp4'),
 ('CC_1916_12_04_TheRink','شارلي شابلن: حلبة التزلج','The Rink',1916,19,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1916_12_04_TheRink/CC_1916_12_04_TheRink_512kb.mp4'),
 ('CC_1916_05_15_TheFloorwalker','شارلي شابلن: مشرف المتجر','The Floorwalker',1916,19,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1916_05_15_TheFloorwalker/CC_1916_05_15_TheFloorwalker_512kb.mp4'),
 ('CC_1917_04_16_TheCure','شارلي شابلن: العلاج','The Cure',1917,19,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1917_04_16_TheCure/CC_1917_04_16_TheCure_512kb.mp4'),
 ('CC_1915_10_04_CharlieShanghaied','شارلي شابلن: شارلي المخطوف','Shanghaied',1915,23,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1915_10_04_CharlieShanghaied/CC_1915_10_04_CharlieShanghaied_512kb.mp4'),
 ('CC_1916_09_04_TheCount','شارلي شابلن: الكونت','The Count',1916,20,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1916_09_04_TheCount/CC_1916_09_04_TheCount_512kb.mp4'),
 ('CC_1916_08_07_One_A_M','شارلي شابلن: الواحدة صباحاً','One A.M.',1916,17,'United States of America','en','Charlie Chaplin',array['comedy'],'https://archive.org/download/CC_1916_08_07_One_A_M/CC_1916_08_07_One_A_M_512kb.mp4'),
 ('CC_1914_02_07_KidsAutoRaceAtVenice','شارلي شابلن: سباق السيارات الصغيرة في البندقية','Kid Auto Races at Venice',1914,6,'United States of America','en','Henry Lehrman',array['comedy'],'https://archive.org/download/CC_1914_02_07_KidsAutoRaceAtVenice/CC_1914_02_07_KidsAutoRaceAtVenice_512kb.mp4'),
 -- المجموعة (ب)
 ('Night.Of.The.Living.Dead_1080p','ليلة الموتى الأحياء','Night of the Living Dead',1968,96,'United States of America','en','George A. Romero',array['horror'],'https://archive.org/download/Night.Of.The.Living.Dead_1080p/NightOfTheLivingDead.mp4'),
 ('captain-kidd-1945_202609','الكابتن كيد','Captain Kidd',1945,89,'United States of America','en','Rowland V. Lee',array['action'],'https://archive.org/download/captain-kidd-1945_202609/CaptainKidd_512kb.mp4'),
 ('the-thirteenth-chair_1929','الكرسي الثالث عشر','The Thirteenth Chair',1929,72,'United States of America','en','Tod Browning',array['thriller'],'https://archive.org/download/the-thirteenth-chair_1929/the-thirteenth-chair_1929.mp4'),
 ('house_on_haunted_hill_ipod','البيت على التل المسكون','House on Haunted Hill',1959,75,'United States of America','en','William Castle',array['horror'],'https://archive.org/download/house_on_haunted_hill_ipod/house_on_haunted_hill_512kb.mp4'),
 ('CarnivalofSouls','كرنفال الأرواح','Carnival of Souls',1962,83,'United States of America','en','Herk Harvey',array['horror'],'https://archive.org/download/CarnivalofSouls/CarnivalOfSouls_512kb.mp4'),
 ('teenagers_from_outerspace','مراهقون من الفضاء','Teenagers from Outer Space',1959,85,'United States of America','en','Tom Graeff',array['sci-fi'],'https://archive.org/download/teenagers_from_outerspace/Teenagers_from_Outer_Space_512kb.mp4'),
 ('white_zombie','الزومبي الأبيض','White Zombie',1932,65,'United States of America','en','Victor Halperin',array['horror'],'https://archive.org/download/white_zombie/white_zombie_512kb.mp4'),
 ('TheMostDangerousGame','أخطر لعبة','The Most Dangerous Game',1932,63,'United States of America','en','Irving Pichel, Ernest B. Schoedsack',array['action','thriller'],'https://archive.org/download/TheMostDangerousGame/TheMostDangerousGame_512kb.mp4'),
 ('TheScreamingSkull','الجمجمة الصارخة','The Screaming Skull',1958,67,'United States of America','en','Alex Nicol',array['horror'],'https://archive.org/download/TheScreamingSkull/TheScreamingSkull.mp4'),
 ('the_brain_that_wouldnt_die','الدماغ الذي لا يموت','The Brain That Wouldn''t Die',1962,71,'United States of America','en','Joseph Green',array['horror','sci-fi'],'https://archive.org/download/the_brain_that_wouldnt_die/the_brain_that_wouldnt_die_512kb.mp4'),
 ('TheVampireBat','الخفاش مصاص الدماء','The Vampire Bat',1933,60,'United States of America','en','Frank R. Strayer',array['horror'],'https://archive.org/download/TheVampireBat/TheVampireBat_512kb.mp4'),
 ('lost_world','العالم المفقود','The Lost World',1925,68,'United States of America','en','Harry O. Hoyt',array['action','sci-fi'],'https://archive.org/download/lost_world/lost_world_512kb.mp4'),
 ('7.3-d.-o.-a.-1949','وصل ميتاً','D.O.A.',1949,84,'United States of America','en','Rudolph Maté',array['thriller'],'https://archive.org/download/7.3-d.-o.-a.-1949/7.3%20D.O.A.%C2%A0%281949%29%C2%A0.ia.mp4'),
 ('meet_john_doe','قابل جون دو','Meet John Doe',1941,123,'United States of America','en','Frank Capra',array['drama','comedy'],'https://archive.org/download/meet_john_doe/meet_john_doe_512kb.mp4'),
 ('iron_mask','القناع الحديدي','The Iron Mask',1929,72,'United States of America','en','Allan Dwan',array['action'],'https://archive.org/download/iron_mask/iron_mask_512kb.mp4'),
 ('mr_robinson_crusoe','السيد روبنسون كروزو','Mr. Robinson Crusoe',1932,71,'United States of America','en','A. Edward Sutherland',array['action','comedy'],'https://archive.org/download/mr_robinson_crusoe/video_512kb.mp4')
),
new_movies as (
  insert into public.movies (title_ar, title_en, poster_url, backdrop_url, release_year, country, language, origin, runtime_minutes, director, is_published)
  select s.title_ar, s.title_en, 'https://archive.org/services/img/' || s.ident, 'https://archive.org/services/img/' || s.ident,
         s.yr, s.country, s.lang, 'foreign', s.mins, s.director, true
  from src s
  where not exists (select 1 from public.movies m where m.title_en = s.title_en and m.release_year = s.yr)
  returning id, title_en, release_year
),
vs as (
  insert into public.video_sources (movie_id, label, url, type, sort_order)
  select n.id, 'Internet Archive (MP4)', s.url, 'mp4', 0
  from new_movies n join src s on s.title_en = n.title_en and s.yr = n.release_year
  returning 1
),
gl as (
  insert into public.movie_genres (movie_id, genre_id)
  select distinct n.id, g.id
  from new_movies n
  join src s on s.title_en = n.title_en and s.yr = n.release_year
  cross join lateral unnest(s.genres) as gs(slug)
  join public.genres g on g.slug = gs.slug
  returning 1
)
select (select count(*) from new_movies) as movies, (select count(*) from vs) as sources, (select count(*) from gl) as genre_links;
