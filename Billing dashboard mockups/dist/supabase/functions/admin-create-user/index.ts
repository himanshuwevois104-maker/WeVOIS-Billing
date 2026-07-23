// WeVois Billing — Edge Function: admin-create-user
// Deploy:  supabase functions deploy admin-create-user
//
// Creates a new auth user (service-role) after verifying the CALLER is an admin,
// sets their profile role + name, and assigns sites. Body:
//   { email, password, full_name, role, siteIds: number[] }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url        = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    // 1. Verify the caller is a signed-in admin
    const asCaller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: uErr } = await asCaller.auth.getUser();
    if (uErr || !user) return json({ error: "Not signed in" }, 401);

    const { data: prof } = await asCaller
      .from("user_profiles").select("role").eq("id", user.id).maybeSingle();
    if (prof?.role !== "admin") return json({ error: "Admins only" }, 403);

    // 2. Create the new user with the service-role client
    const { email, password, full_name, role, siteIds } = await req.json();
    if (!email || !password || !role) return json({ error: "Missing fields" }, 400);

    const admin = createClient(url, serviceKey);
    const { data: created, error: cErr } = await admin.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: { full_name, role },
    });
    if (cErr) return json({ error: cErr.message }, 400);

    const newId = created.user.id;

    // 3. Ensure profile has the right role/name/email (trigger may have run already)
    await admin.from("user_profiles")
      .upsert({ id: newId, full_name: full_name || email.split("@")[0], role, email });

    // 4. Assign sites (managers)
    if (Array.isArray(siteIds) && siteIds.length) {
      await admin.from("site_assignments")
        .insert(siteIds.map((site_id: number) => ({ user_id: newId, site_id })));
    }

    return json({ ok: true, id: newId });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });
}
