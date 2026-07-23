// WeVois Billing — Edge Function: ageing-emails
// Runs on a schedule (daily 8 AM). For every UNPAID bill it works out the debtor
// ageing bucket and sends the right email:
//   0–30  → Appreciation mail          (to the site's Billing Manager)
//   31–60 → Alert mail + clarification (Billing Manager — remark required in app)
//   61–90 → Ultra-alert mail           (Billing Manager + Leadership)
//   90+   → Daily 8 AM mail            (Billing Manager + Leadership — reason required)
//
// Deploy:  supabase functions deploy ageing-emails
// Set the email provider key:  supabase secrets set RESEND_API_KEY=...  FROM_EMAIL=billing@wevois.com
// Schedule it: see supabase/07_ageing_cron.sql

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DAY = 86400000;

function bucketOf(days: number) {
  if (days <= 30) return { key: "g0", range: "0–30 days",  subject: "✅ Payment on track", tone: "appreciation", toLeadership: false, reason: false };
  if (days <= 60) return { key: "g1", range: "31–60 days", subject: "⚠ Payment alert — clarification needed", tone: "alert", toLeadership: false, reason: true };
  if (days <= 90) return { key: "g2", range: "61–90 days", subject: "🔴 ULTRA ALERT — payment overdue", tone: "ultra", toLeadership: true, reason: true };
  return              { key: "g3", range: "90+ days",   subject: "🚨 CRITICAL — payment 90+ days overdue", tone: "critical", toLeadership: true, reason: true };
}

function body(site: string, month: string, days: number, b: ReturnType<typeof bucketOf>) {
  const lines: string[] = [`Site: ${site}`, `Billing month: ${month}`, `Outstanding: ${days} days (${b.range})`];
  if (b.tone === "appreciation") lines.push("", "Payment is within the healthy window. Thank you — keep it up.");
  if (b.tone === "alert")        lines.push("", "This bill has crossed 30 days. Please add a clarification remark in the Executive App explaining the delay.");
  if (b.tone === "ultra")        lines.push("", "This bill has crossed 60 days. Immediate follow-up required. Leadership has been copied.");
  if (b.tone === "critical")     lines.push("", "This bill is 90+ days overdue. A written reason from the Billing Manager is required. This reminder will repeat every morning until the bill is paid.");
  return lines.join("\n");
}

async function sendEmail(to: string[], subject: string, text: string) {
  const key = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("FROM_EMAIL") || "wevoisbilling@gmail.com";
  if (!key) { console.log("[dry-run] would email", to, subject); return; }
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to, subject, text }),
  });
}

Deno.serve(async () => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Unpaid bills
  const { data: bills } = await sb.from("bills").select("*").neq("status", "Paid");
  const { data: sites } = await sb.from("sites").select("*");
  const { data: profs } = await sb.from("user_profiles").select("id,email,role");
  const { data: asg }   = await sb.from("site_assignments").select("*");

  const siteById = Object.fromEntries((sites || []).map((s: any) => [s.id, s]));
  const emailById = Object.fromEntries((profs || []).map((p: any) => [p.id, p.email]));
  const leadershipEmails = (profs || []).filter((p: any) => p.role === "leadership" && p.email).map((p: any) => p.email);
  const managersBySite: Record<number, string[]> = {};
  (asg || []).forEach((a: any) => {
    const em = emailById[a.user_id];
    if (em) (managersBySite[a.site_id] ||= []).push(em);
  });

  let sent = 0;
  for (const bill of bills || []) {
    const start = bill.submitted_at ? new Date(bill.submitted_at).getTime() : null;
    if (start == null) continue;
    const days = Math.max(0, Math.floor((Date.now() - start) / DAY));
    const b = bucketOf(days);
    // Only 90+ mails every day; the others fire once you wire a "last sent" guard.
    // (Kept simple here — the cron runs daily; add a sent-log table to throttle 0–60 if needed.)
    const site = siteById[bill.site_id];
    if (!site) continue;
    const to = [...(managersBySite[bill.site_id] || []), ...(b.toLeadership ? leadershipEmails : [])];
    if (!to.length) continue;
    await sendEmail(to, `${b.subject} — ${site.name}`, body(site.name, bill.month_key, days, b));
    sent++;
  }

  return new Response(JSON.stringify({ ok: true, sent }), { headers: { "Content-Type": "application/json" } });
});
