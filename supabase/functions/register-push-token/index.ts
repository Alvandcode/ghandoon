// Registers a device FCM token for a username (used before Supabase Auth).
// POST {username, token} → upserts profiles(username, fcm_token) with service_role.
// RLS stays locked: clients can NOT write profiles directly.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("method not allowed", { status: 405 });
    }
    const { username, token } = await req.json();
    const name = String(username ?? "").trim().slice(0, 64);
    const tok = String(token ?? "").trim();
    if (name.length < 1 || tok.length < 20 || tok.length > 4096) {
      return new Response("bad request", { status: 400 });
    }
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const db = createClient(url, serviceKey);
    const { error } = await db
      .from("profiles")
      .upsert({ username: name, fcm_token: tok }, { onConflict: "username" });
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
