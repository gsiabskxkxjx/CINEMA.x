// CINEMA X — Edge Function: video-upload-url
// تُصدر روابط رفع/حذف موقّعة لاستضافات تخزين متوافقة مع S3 (Cloudflare R2, Backblaze B2, أو أي مزود S3)
// حتى يرفع المسؤول ملف الفيديو من هاتفه مباشرة إلى الاستضافة بدون المرور بـ Supabase Storage
// (الذي تحدّه الخطة المجانية بـ 50 MB للملف).
//
// الأمان:
//  - مفاتيح الاستضافة أسرار خادم (Edge Function secrets) ولا تصل التطبيق ولا المستودع.
//  - المصادقة داخل الدالة: مستخدم مسجل ودوره admin (is_admin())، مثل tmdb-import.
//  - التطبيق يحصل على رابط مؤقت (ساعة واحدة) لملف واحد فقط، لا على المفاتيح.
//  - الحذف مسموح فقط لملفات داخل uploads/ في حاويات المشروع المضبوطة.
//
// الأسرار (لكل مزود P من R2 / B2 / S3 — يظهر المزود في التطبيق فقط إذا اكتملت أسراره الخمسة الأساسية):
//   P_ENDPOINT            مثال R2: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
//                         مثال B2: https://s3.us-west-004.backblazeb2.com
//   P_BUCKET              اسم الحاوية
//   P_ACCESS_KEY_ID       مفتاح S3 (يفضّل أن يكون محصوراً بهذه الحاوية فقط)
//   P_SECRET_ACCESS_KEY   السرّ المقابل
//   P_PUBLIC_BASE_URL     الأساس العام لقراءة الملفات: R2 → https://pub-xxxx.r2.dev  |  B2 → https://fNNN.backblazeb2.com/file/<bucket>
//   P_REGION              اختياري (R2 = auto، B2 يُستخرج من الـ endpoint، غير ذلك us-east-1)
//
// الاستدعاء: POST { action: "providers" }
//            POST { action: "sign", provider: "r2", ext: "mp4", size: 123456789 }
//            POST { action: "delete", url: "<الرابط العام للملف>" }
// برأس Authorization: Bearer <access_token للأدمن>

import { createClient } from "npm:@supabase/supabase-js@2";
import { presign } from "./sigv4.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
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

const MIME: Record<string, string> = {
  mp4: "video/mp4",
  m4v: "video/mp4",
  webm: "video/webm",
  mov: "video/quicktime",
  mkv: "video/x-matroska",
};

// حدّ الطلب الواحد (PUT) في R2 و B2 قرابة 5 GiB؛ نتحفّظ عند 5 GB عشرية.
const MAX_BYTES = 5_000_000_000;
const SIGN_SECONDS = 3600;
const IDS = ["r2", "b2", "s3"] as const;

type Provider = {
  id: string;
  endpoint: string;
  region: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  publicBase: string;
};

function loadProvider(id: string): Provider | null {
  const p = id.toUpperCase();
  const endpoint = (Deno.env.get(`${p}_ENDPOINT`) ?? "").trim().replace(/\/+$/, "");
  const bucket = (Deno.env.get(`${p}_BUCKET`) ?? "").trim();
  const accessKeyId = (Deno.env.get(`${p}_ACCESS_KEY_ID`) ?? "").trim();
  const secretAccessKey = (Deno.env.get(`${p}_SECRET_ACCESS_KEY`) ?? "").trim();
  const publicBase = (Deno.env.get(`${p}_PUBLIC_BASE_URL`) ?? "").trim().replace(/\/+$/, "");
  if (!endpoint || !bucket || !accessKeyId || !secretAccessKey || !publicBase) return null;
  if (!endpoint.startsWith("https://") || !publicBase.startsWith("https://")) return null;

  let region = (Deno.env.get(`${p}_REGION`) ?? "").trim();
  if (!region) {
    if (id === "r2") region = "auto";
    else {
      const m = endpoint.match(/s3\.([a-z0-9-]+)\.backblazeb2\.com/);
      region = m ? m[1] : "us-east-1";
    }
  }
  return { id, endpoint, region, bucket, accessKeyId, secretAccessKey, publicBase };
}

function configured(): Provider[] {
  return IDS.map(loadProvider).filter((p): p is Provider => p !== null);
}

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

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const action = String(body?.action ?? "");
  const all = configured();

  try {
    if (action === "providers") {
      return json({ providers: all.map((p) => p.id) });
    }

    if (action === "sign") {
      const provider = all.find((p) => p.id === String(body?.provider ?? ""));
      if (!provider) return json({ error: "provider_not_configured" }, 400);

      const ext = String(body?.ext ?? "").toLowerCase().replace(/^\./, "");
      const mime = MIME[ext];
      if (!mime) return json({ error: "unsupported_type", allowed: Object.keys(MIME) }, 400);

      const size = Number(body?.size);
      if (!Number.isFinite(size) || size <= 0) return json({ error: "bad_size" }, 400);
      if (size > MAX_BYTES) return json({ error: "too_large", max_bytes: MAX_BYTES }, 413);

      const rnd = crypto.randomUUID().replace(/-/g, "").slice(0, 12);
      const key = `uploads/${Date.now()}_${rnd}.${ext}`;
      const uploadUrl = await presign({
        method: "PUT",
        endpoint: provider.endpoint,
        path: `/${provider.bucket}/${key}`,
        region: provider.region,
        accessKeyId: provider.accessKeyId,
        secretAccessKey: provider.secretAccessKey,
        expires: SIGN_SECONDS,
      });
      return json({
        method: "PUT",
        upload_url: uploadUrl,
        public_url: `${provider.publicBase}/${key}`,
        content_type: mime,
        key,
      });
    }

    if (action === "delete") {
      const url = String(body?.url ?? "");
      for (const p of all) {
        const prefix = `${p.publicBase}/`;
        if (!url.startsWith(prefix)) continue;
        let key = "";
        try {
          key = decodeURIComponent(url.slice(prefix.length).split("?")[0]);
        } catch {
          return json({ managed: false });
        }
        // نحذف فقط ما رفعه التطبيق (uploads/) ولا نلمس ملفات أخرى في نفس الحاوية.
        if (!key.startsWith("uploads/") || key.includes("..") || key.includes("//")) return json({ managed: false });
        const deleteUrl = await presign({
          method: "DELETE",
          endpoint: p.endpoint,
          path: `/${p.bucket}/${key}`,
          region: p.region,
          accessKeyId: p.accessKeyId,
          secretAccessKey: p.secretAccessKey,
          expires: SIGN_SECONDS,
        });
        return json({ managed: true, method: "DELETE", delete_url: deleteUrl });
      }
      return json({ managed: false });
    }

    return json({ error: "unknown_action", valid: ["providers", "sign", "delete"] }, 400);
  } catch (e) {
    return json({ error: "internal", message: String((e as Error)?.message ?? e) }, 500);
  }
});
