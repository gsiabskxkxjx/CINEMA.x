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
-- بعد إنشاء أول حساب من التطبيق، اجعله مسؤولاً بتشغيل (غيّر البريد):
--
--   update public.profiles set role = 'admin' where email = 'you@example.com';
--
-- =====================================================================
