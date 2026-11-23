// CINEMA X — Edge Function: tmdb-import
// تستورد بيانات وصفية وبوسترات من TMDB (عناوين، ملخصات، أنواع، ممثلون) إلى جداول movies/series.
// لا تستورد أي فيديو ولا أي رابط تشغيل. الصور تبقى على image.tmdb.org (رابط فقط).
//
// الأمان:
//  - مفتاح TMDB يُقرأ من سرّ الخادم TMDB_API_KEY فقط، ولا يُرسل للتطبيق ولا يُكتب في الكود.
//  - المصادقة داخل الدالة: يجب أن يكون المستدعي مستخدماً مسجلاً ودوره admin (الدالة is_admin()).
//  - الكتابة تتم بجلسة المسؤول نفسها فتخضع لسياسات RLS (لا نستخدم مفتاح service_role).
//
// الاستدعاء: POST { "category": "action-movies" } برأس Authorization: Bearer <access_token للأدمن>
// فئة واحدة في كل طلب حتى لا يتجاوز الطلب حدّ الزمن. الفئات المتاحة في CATS أدناه.

import { createClient } from "npm:@supabase/supabase-js@2";

const TMDB = "https://api.themoviedb.org/3";
const IMG = "https://image.tmdb.org/t/p";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
// المفتاح العام (publishable) عام بطبيعته، وهو نفسه الموجود في التطبيق.
const PUBLIC_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "sb_publishable_WSfDgvdWvV2fji2KM7QmCQ_SIOrj3RH";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------
// تعريف الفئات (نفس slug الموجود في جدول categories)
// ---------------------------------------------------------------------
type Part = {
  type: "movie" | "tv";
  params: Record<string, string>;
  count: number;
  excludeAr?: boolean;
  anime?: boolean;
};

const CATS: Record<string, Part[]> = {
  "action-movies": [{ type: "movie", params: { with_genres: "28", "vote_count.gte": "500" }, count: 100 }],
  "horror-movies": [{ type: "movie", params: { with_genres: "27", "vote_count.gte": "300" }, count: 100 }],
  "scifi-movies": [{ type: "movie", params: { with_genres: "878", "vote_count.gte": "500" }, count: 100 }],
  "comedy-movies": [{ type: "movie", params: { with_genres: "35", "vote_count.gte": "500" }, count: 100 }],
  "arabic-movies": [{ type: "movie", params: { with_original_language: "ar", "vote_count.gte": "3" }, count: 100 }],
  "foreign-movies": [{ type: "movie", params: { "vote_count.gte": "1000" }, count: 100, excludeAr: true }],
  "arabic-series": [{ type: "tv", params: { with_original_language: "ar", "vote_count.gte": "2" }, count: 100 }],
  "foreign-series": [{ type: "tv", params: { "vote_count.gte": "500" }, count: 100, excludeAr: true }],
  "anime": [
    { type: "tv", params: { with_genres: "16", with_original_language: "ja", "vote_count.gte": "100" }, count: 100, anime: true },
    { type: "movie", params: { with_genres: "16", with_original_language: "ja", "vote_count.gte": "100" }, count: 50, anime: true },
  ],
};

// تحويل أنواع TMDB (أفلام + مسلسلات) إلى slug الأنواع عندنا
const GENRE_MAP: Record<number, string> = {
  28: "action", 10759: "action",
  27: "horror",
  878: "sci-fi", 10765: "sci-fi",
  35: "comedy",
  18: "drama",
  10749: "romance",
  53: "thriller", 9648: "thriller", 80: "thriller",
  16: "animation",
  99: "documentary",
  10751: "family", 10762: "family",
};

// ---------------------------------------------------------------------
// أدوات
// ---------------------------------------------------------------------
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function tmdb(key: string, path: string, params: Record<string, string> = {}): Promise<any> {
  const u = new URL(TMDB + path);
  u.searchParams.set("api_key", key);
  for (const [k, v] of Object.entries(params)) u.searchParams.set(k, v);
  for (let i = 0; i < 4; i++) {
    const r = await fetch(u);
    if (r.status === 429 || r.status >= 500) {
      await sleep(700 * (i + 1));
      continue;
    }
    if (!r.ok) throw new Error(`TMDB ${r.status} ${path}`); // بدون الاستعلام حتى لا يظهر المفتاح
    return await r.json();
  }
  throw new Error(`TMDB retries exhausted ${path}`);
}

async function mapLimit<T, R>(items: T[], limit: number, fn: (x: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const i = next++;
      if (i >= items.length) break;
      out[i] = await fn(items[i]);
    }
  });
  await Promise.all(workers);
  return out;
}

const img = (p: string | null | undefined, size: string) => (p ? `${IMG}/${size}${p}` : null);
const yearOf = (d?: string) => {
  const y = parseInt((d ?? "").slice(0, 4), 10);
  return y >= 1888 && y <= 2100 ? y : null;
};
const ratingOf = (v?: number) => (v && v > 0 ? Math.min(10, Math.round(v * 10) / 10) : null);
const posInt = (v: unknown) => (typeof v === "number" && v > 0 ? Math.round(v) : null);
const clean = (s?: string | null) => {
  const t = (s ?? "").trim();
  return t.length ? t : null;
};

async function collect(key: string, part: Part): Promise<any[]> {
  const out: any[] = [];
  const seen = new Set<number>();
  for (let page = 1; page <= 12 && out.length < part.count; page++) {
    const data = await tmdb(key, `/discover/${part.type}`, {
      ...part.params,
      language: "en-US",
      sort_by: "popularity.desc",
      include_adult: "false",
      page: String(page),
    });
    for (const it of data.results ?? []) {
      if (!it.poster_path) continue; // الهدف بوسترات: نتجاوز ما لا بوستر له
      if (part.excludeAr && it.original_language === "ar") continue;
      if (seen.has(it.id)) continue;
      seen.add(it.id);
      out.push(it);
      if (out.length >= part.count) break;
    }
    if (page >= (data.total_pages ?? 1)) break;
  }
  return out;
}

function chunk<T>(arr: T[], n: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

// ---------------------------------------------------------------------
// المعالج
// ---------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // --- المصادقة: مستخدم مسجل + مسؤول ---
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) return json({ error: "unauthorized" }, 401);
  const token = auth.slice(7).trim();

  const sb = createClient(SUPABASE_URL, PUBLIC_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userErr } = await sb.auth.getUser(token);
  if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);
  const { data: isAdmin, error: adminErr } = await sb.rpc("is_admin");
  if (adminErr || isAdmin !== true) return json({ error: "forbidden" }, 403);

  // --- المدخلات ---
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const category = String(body?.category ?? "");
  const parts = CATS[category];
  if (!parts) return json({ error: "unknown_category", valid: Object.keys(CATS) }, 400);

  const key = Deno.env.get("TMDB_API_KEY");
  if (!key) return json({ error: "tmdb_key_missing" }, 500);

  try {
    // خريطة الأنواع عندنا
    const { data: genreRows, error: gErr } = await sb.from("genres").select("id,slug");
    if (gErr) throw new Error(`genres: ${gErr.message}`);
    const genreId = new Map<string, string>((genreRows ?? []).map((g: any) => [g.slug, g.id]));

    const now = new Date().toISOString();
    const stats = { category, fetched: 0, detail_failures: 0, movies: 0, series: 0, actors: 0, genre_links: 0, actor_links: 0 };

    for (const part of parts) {
      const items = await collect(key, part);
      stats.fetched += items.length;

      // تفاصيل بالعربية + الطاقم (مع تحمّل الفشل: نكمل ببيانات القائمة الإنجليزية)
      const details = await mapLimit(items, 8, async (it) => {
        try {
          return await tmdb(key, `/${part.type}/${it.id}`, { language: "ar", append_to_response: "credits" });
        } catch {
          stats.detail_failures++;
          return null;
        }
      });

      const isMovie = part.type === "movie";
      const table = isMovie ? "movies" : "series";
      const genreTable = isMovie ? "movie_genres" : "series_genres";
      const actorTable = isMovie ? "movie_actors" : "series_actors";
      const fk = isMovie ? "movie_id" : "series_id";

      const rows: any[] = [];
      const meta = new Map<number, { genres: string[]; cast: any[] }>();
      const actorMap = new Map<number, any>();

      items.forEach((it, i) => {
        const d = details[i];
        const titleEn = clean(isMovie ? it.title : it.name);
        const titleAr = clean(isMovie ? d?.title : d?.name) ?? titleEn ?? "—";
        const ovEn = clean(it.overview);
        const ovAr = clean(d?.overview) ?? ovEn;
        const lang = it.original_language ?? null;

        const slugs = new Set<string>();
        const gids: number[] = (d?.genres?.map((g: any) => g.id)) ?? it.genre_ids ?? [];
        for (const g of gids) if (GENRE_MAP[g]) slugs.add(GENRE_MAP[g]);
        if (part.anime) {
          slugs.add("anime");
          slugs.add("animation");
        }

        const crewDirector = isMovie
          ? d?.credits?.crew?.find((c: any) => c.job === "Director")?.name
          : d?.created_by?.[0]?.name;
        const country = isMovie
          ? d?.production_countries?.[0]?.name
          : (d?.production_countries?.[0]?.name ?? d?.origin_country?.[0]);

        rows.push({
          tmdb_id: it.id,
          title_ar: titleAr,
          title_en: titleEn,
          overview_ar: ovAr,
          overview_en: ovEn,
          poster_url: img(it.poster_path, "w500"),
          backdrop_url: img(it.backdrop_path, "w1280"),
          release_year: yearOf(isMovie ? it.release_date : it.first_air_date),
          country: clean(country),
          language: lang,
          origin: lang === "ar" ? "arab" : "foreign",
          rating: ratingOf(it.vote_average),
          runtime_minutes: isMovie
            ? posInt(d?.runtime)
            : posInt(d?.episode_run_time?.[0] ?? d?.last_episode_to_air?.runtime),
          director: clean(crewDirector),
          tmdb_synced_at: now,
        });

        const seenCast = new Set<number>();
        const cast = (d?.credits?.cast ?? [])
          .filter((c: any) => c?.id && !seenCast.has(c.id) && seenCast.add(c.id))
          .slice(0, 8);
        for (const c of cast) {
          if (!c?.id || !clean(c.name)) continue;
          if (!actorMap.has(c.id)) {
            actorMap.set(c.id, {
              tmdb_id: c.id,
              name_ar: c.name.trim(),
              name_en: c.name.trim(),
              photo_url: img(c.profile_path, "w185"),
            });
          }
        }
        meta.set(it.id, { genres: [...slugs], cast });
      });

      // العناوين (تحديث بدل تكرار حسب tmdb_id؛ لا نلمس is_featured/is_premium/is_published/view_count)
      const idByTmdb = new Map<number, string>();
      for (const part_ of chunk(rows, 100)) {
        const { data, error } = await sb.from(table).upsert(part_, { onConflict: "tmdb_id" }).select("id,tmdb_id");
        if (error) throw new Error(`${table}: ${error.message}`);
        for (const r of data ?? []) idByTmdb.set(r.tmdb_id, r.id);
      }
      if (isMovie) stats.movies += idByTmdb.size;
      else stats.series += idByTmdb.size;

      // الممثلون
      const actorIdByTmdb = new Map<number, string>();
      for (const part_ of chunk([...actorMap.values()], 200)) {
        const { data, error } = await sb.from("actors").upsert(part_, { onConflict: "tmdb_id" }).select("id,tmdb_id");
        if (error) throw new Error(`actors: ${error.message}`);
        for (const r of data ?? []) actorIdByTmdb.set(r.tmdb_id, r.id);
      }
      stats.actors += actorIdByTmdb.size;

      // روابط الأنواع والممثلين
      const gLinks: any[] = [];
      const aLinks: any[] = [];
      for (const [tid, m] of meta) {
        const id = idByTmdb.get(tid);
        if (!id) continue;
        for (const slug of m.genres) {
          const gid = genreId.get(slug);
          if (gid) gLinks.push({ [fk]: id, genre_id: gid });
        }
        m.cast.forEach((c: any, idx: number) => {
          const aid = actorIdByTmdb.get(c.id);
          if (aid) aLinks.push({ [fk]: id, actor_id: aid, character_name: clean(c.character), sort_order: idx });
        });
      }
      for (const part_ of chunk(gLinks, 500)) {
        const { error } = await sb.from(genreTable).upsert(part_, { onConflict: `${fk},genre_id`, ignoreDuplicates: true });
        if (error) throw new Error(`${genreTable}: ${error.message}`);
      }
      for (const part_ of chunk(aLinks, 500)) {
        const { error } = await sb.from(actorTable).upsert(part_, { onConflict: `${fk},actor_id` });
        if (error) throw new Error(`${actorTable}: ${error.message}`);
      }
      stats.genre_links += gLinks.length;
      stats.actor_links += aLinks.length;
    }

    return json({ ok: true, ...stats });
  } catch (e) {
    return json({ ok: false, error: String((e as Error)?.message ?? e) }, 500);
  }
});
