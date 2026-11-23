// AWS Signature V4 — روابط موقّعة (Presigned URL) بطريقة الاستعلام، باستخدام WebCrypto فقط.
// تعمل مع أي تخزين متوافق مع S3 (Cloudflare R2, Backblaze B2, Wasabi, Filebase, …).
// الحمولة UNSIGNED-PAYLOAD والترويسة الموقّعة الوحيدة هي host، فيستطيع التطبيق رفع الملف مباشرة
// بطلب PUT واحد دون أن تمرّ البيانات عبر الخادم، ودون أن يعرف التطبيق مفاتيح التخزين.

const enc = new TextEncoder();

function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function hmac(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return crypto.subtle.sign("HMAC", k, enc.encode(data));
}

async function sha256Hex(data: string): Promise<string> {
  return toHex(await crypto.subtle.digest("SHA-256", enc.encode(data)));
}

/** ترميز URI حسب AWS: يترك A-Z a-z 0-9 - _ . ~ ويرمّز البقية. */
export function awsEncode(s: string): string {
  return encodeURIComponent(s).replace(/[!'()*]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
}

export type PresignOptions = {
  method: "PUT" | "GET" | "DELETE";
  /** مثل https://<account>.r2.cloudflarestorage.com (بدون مسار) */
  endpoint: string;
  /** المسار غير المرمّز ويبدأ بـ / مثل /bucket/uploads/file.mp4 */
  path: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  /** مدة صلاحية الرابط بالثواني (الحد الأقصى 604800) */
  expires: number;
  now?: Date;
};

export async function presign(o: PresignOptions): Promise<string> {
  const u = new URL(o.endpoint);
  const host = u.host;
  const now = o.now ?? new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, ""); // 20130524T000000Z
  const date = amzDate.slice(0, 8);
  const scope = `${date}/${o.region}/s3/aws4_request`;

  const canonicalUri = o.path.split("/").map(awsEncode).join("/");

  const query: Record<string, string> = {
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": `${o.accessKeyId}/${scope}`,
    "X-Amz-Date": amzDate,
    "X-Amz-Expires": String(o.expires),
    "X-Amz-SignedHeaders": "host",
  };
  const canonicalQuery = Object.keys(query)
    .sort()
    .map((k) => `${awsEncode(k)}=${awsEncode(query[k])}`)
    .join("&");

  const canonicalRequest = [
    o.method,
    canonicalUri,
    canonicalQuery,
    `host:${host}\n`,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");

  const stringToSign = ["AWS4-HMAC-SHA256", amzDate, scope, await sha256Hex(canonicalRequest)].join("\n");

  const kDate = await hmac(enc.encode("AWS4" + o.secretAccessKey), date);
  const kRegion = await hmac(kDate, o.region);
  const kService = await hmac(kRegion, "s3");
  const kSigning = await hmac(kService, "aws4_request");
  const signature = toHex(await hmac(kSigning, stringToSign));

  return `${u.protocol}//${host}${canonicalUri}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}
