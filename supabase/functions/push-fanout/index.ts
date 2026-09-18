// Webhook receiver for postgres changes on public.orders.
// SELF-CONTAINED single file (no imports) so it can be pasted directly
// into Dashboard → Edge Functions → Editor.
// Create TWO Database Webhooks (Dashboard → Database → Webhooks):
//   1) orders-insert → POST .../functions/v1/push-fanout, events=INSERT, table=orders
//   2) orders-update → same URL, events=UPDATE, table=orders
// Optional: set secret PUSH_WEBHOOK_SECRET (function env) and paste the same
// value in the webhook HTTP Headers as x-webhook-secret.
//
// NOTE: topic logic mirrors lib/utils/push_topics.dart in the app —
// if you change one, change the other.

// ---------- topics ----------
const adminPushTopic = "orders_admin";

function pushTopicForUser(username: string): string {
  const name = (username ?? "").trim().toLowerCase();
  if (!name) return "user_guest";
  const bytes = new TextEncoder().encode(name);
  let out = "user_";
  for (const b of bytes) {
    if (
      (b >= 0x30 && b <= 0x39) || // 0-9
      (b >= 0x61 && b <= 0x7a) || // a-z
      b === 0x2d || // -
      b === 0x2e || // .
      b === 0x5f || // _
      b === 0x7e // ~
    ) {
      out += String.fromCharCode(b);
    } else {
      out += "%" + b.toString(16).toUpperCase().padStart(2, "0");
    }
  }
  return out.length <= 900 ? out : out.slice(0, 900);
}

const statusFa: Record<string, string> = {
  pending: "ثبت‌شده، در انتظار بررسی مدیر",
  awaiting_payment: "در انتظار پرداخت",
  receipt_sent: "فیش ارسال شد، در انتظار تایید",
  approved: "تایید شد",
  ready: "آماده تحویل",
  delivered: "تحویل شد",
  cancelled: "لغو شد",
};

function statusFaOf(status: string): string {
  return statusFa[status] ?? status;
}

// ---------- minimal FCM HTTP v1 sender (no deps) ----------
function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlStr(text: string): string {
  return b64url(new TextEncoder().encode(text));
}

async function fcmAccessToken(
  serviceAccountJson: string,
): Promise<{ token: string; projectId: string }> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const unsigned =
    `${b64urlStr(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.` +
    b64urlStr(JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }));
  const pem = (sa.private_key as string)
    .replace(/-----.*?-----/g, "")
    .replace(/\s/g, "");
  const raw = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    raw.buffer as ArrayBuffer,
    { name: "RSASSA-PKCS1-V1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-V1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  if (!res.ok) throw new Error(`oauth failed: ${res.status}`);
  const j = await res.json();
  return { token: j.access_token as string, projectId: sa.project_id as string };
}

async function sendToTopic(
  accessToken: string,
  projectId: string,
  msg: { topic: string; title: string; body: string; data: Record<string, string> },
): Promise<void> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          topic: msg.topic,
          notification: { title: msg.title, body: msg.body },
          data: msg.data,
        },
      }),
    },
  );
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`fcm send failed: ${res.status} ${t}`);
  }
}

// ---------- handler ----------
Deno.serve(async (req) => {
  try {
    const secret = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
    if (secret && req.headers.get("x-webhook-secret") !== secret) {
      return new Response("forbidden", { status: 403 });
    }
    const payload = await req.json();
    const type = payload.type as string; // INSERT | UPDATE
    const record = payload.record as Record<string, unknown>;
    const old = (payload.old_record ?? {}) as Record<string, unknown>;
    if (!record || !record.id) return new Response("no record", { status: 200 });

    const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
    if (!saJson) return new Response("fcm not configured", { status: 200 });
    const { token, projectId } = await fcmAccessToken(saJson);

    const tracking = String(record.tracking_code ?? record.id ?? "");
    const title0 = String(record.product_title ?? "سفارش جدید");

    if (type === "INSERT") {
      await sendToTopic(token, projectId, {
        topic: adminPushTopic,
        title: "سفارش جدید 🧁",
        body: `${title0} — ${tracking}`,
        data: { orderId: String(record.id), type: "new_order" },
      });
    } else if (type === "UPDATE" && record.status !== old.status) {
      const user = String(record.customer_username ?? "");
      if (!user) return new Response("no owner", { status: 200 });
      const status = String(record.status ?? "");
      await sendToTopic(token, projectId, {
        topic: pushTopicForUser(user),
        title: `سفارش ${tracking} — ${statusFaOf(status)}`,
        body: title0,
        data: { orderId: String(record.id), status, type: "status" },
      });
    }
    return new Response("ok", { status: 200 });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
