# WeVois Billing — Supabase Setup (do this once)

Everything runs in the **Supabase Dashboard**. You only paste SQL **twice** and
click a few buttons. After that, the **admin** creates all other users and cities
from inside the dashboard — no more SQL needed.

---

## STEP A — Run the full setup script

1. Open your project → **SQL Editor** → **New query**.
2. Open the file **`supabase/00_run_all.sql`**, copy **everything**, paste it in.
3. Click **Run**.

This creates all tables, triggers, security rules, and the file-storage bucket.
It's safe to re-run any time.

> No cities are added — the admin adds them later from the app.

---

## STEP B — Create the admin login

1. Go to **Authentication → Users → Add user**.
2. Enter:
   - **Email:** `admin@wevois.com`  *(use your real admin email)*
   - **Password:** choose one
   - ✅ tick **Auto Confirm User**
3. Click **Create user**.

---

## STEP C — Make that user the admin

Back in **SQL Editor → New query**, paste this (match the email from Step B) and **Run**:

```sql
UPDATE user_profiles SET full_name = 'Admin Manager', role = 'admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@wevois.com');
```

---

## STEP D — Turn on the "create user" function (one-time, Supabase CLI)

The admin's **"⚙ Manage users → Create login"** button needs a small server
function (creating logins requires a secret key that can't live in the browser).

In a terminal on your computer:

```bash
npm install -g supabase          # if you don't have the CLI
supabase login
supabase link --project-ref <your-project-ref>   # ref is in Project Settings → General
supabase functions deploy admin-create-user
```

> `<your-project-ref>` is the short ID in your Supabase project URL / settings.
> The function code is already in `supabase/functions/admin-create-user/`.

If you skip Step D, everything else still works — but the admin would have to
create each login manually in Authentication → Users instead of from the app.

---

## DONE — from now on the admin does everything in the app

Log in as the admin, then:

- **⚙ Manage users** — create logins and pick each person's role:
  - **Accounts team** → generates & updates bills
  - **Billing Manager** → sees only their assigned cities (read-only) — tick their cities
  - **Site Manager** → sees only their one city — tick that city
  - **VP / CEO (leadership)** → sees everything, raises flags, requests city changes
  - **Admin** → full control
- **Cities section** — add / rename / delete cities.
- Approve or reject the **city change requests** that VP/CEO send in.

### Who can do what

| Role            | Bills            | Cities              | Flags        | Users        |
|-----------------|------------------|---------------------|--------------|--------------|
| Accounts        | Create / edit all| —                   | resolve      | —            |
| Billing Manager | view assigned    | —                   | —            | —            |
| Site Manager    | view own site    | —                   | —            | —            |
| VP / CEO        | view all         | **request** add/del | **raise**    | —            |
| Admin           | all              | add / edit / delete | all          | create/manage|

---

## Reminder

These changes reach your live site only after you **redeploy to Vercel**
(push to GitHub → Vercel rebuilds).
