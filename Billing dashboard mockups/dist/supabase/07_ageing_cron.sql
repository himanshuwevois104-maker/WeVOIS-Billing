-- WeVois Billing — Schedule the daily 8 AM ageing emails
-- Run AFTER deploying the function:  supabase functions deploy ageing-emails
-- ─────────────────────────────────────────────────────────────────────────────
-- This uses Supabase's built-in pg_cron + pg_net to call the Edge Function
-- every morning at 08:00. Adjust the time (it is in UTC — 08:00 IST = 02:30 UTC).

-- 1. Enable the extensions (Dashboard → Database → Extensions also works)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Schedule it.  Replace <PROJECT-REF> and <ANON-OR-SERVICE-KEY>.
--    08:00 IST  ==  02:30 UTC  →  cron:  '30 2 * * *'
SELECT cron.schedule(
  'ageing-emails-daily',
  '30 2 * * *',
  $$
  SELECT net.http_post(
    url     := 'https://<PROJECT-REF>.functions.supabase.co/ageing-emails',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer <ANON-OR-SERVICE-KEY>"}'::jsonb,
    body    := '{}'::jsonb
  );
  $$
);

-- To change the time later:
--   SELECT cron.unschedule('ageing-emails-daily');
--   then re-run the schedule above with a new cron expression.

-- To see scheduled jobs:
--   SELECT * FROM cron.job;
