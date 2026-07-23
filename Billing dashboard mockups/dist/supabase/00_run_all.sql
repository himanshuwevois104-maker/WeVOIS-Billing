-- ═══════════════════════════════════════════════════════════════════════════
--  WeVois Billing — COMPLETE DATABASE SETUP  (run this whole file at once)
--  Supabase Dashboard → SQL Editor → New query → paste ALL of this → Run
--  Safe to re-run (everything uses IF NOT EXISTS / DROP ... IF EXISTS).
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
--  PART 1 — TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- 1.1 User profiles (extends Supabase Auth) -----------------------------------
CREATE TABLE IF NOT EXISTS user_profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'site_manager',
  email      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Allowed roles
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check
  CHECK (role IN ('accounts','billing_manager','site_manager','leadership','executive','admin'));

-- 1.2 Sites --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sites (
  id     SERIAL PRIMARY KEY,
  name   TEXT NOT NULL,
  region TEXT NOT NULL
);

-- 1.3 Site assignments (user ↔ site) ------------------------------------------
CREATE TABLE IF NOT EXISTS site_assignments (
  user_id UUID    NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  site_id INTEGER NOT NULL REFERENCES sites(id)         ON DELETE CASCADE,
  PRIMARY KEY (user_id, site_id)
);

-- 1.4 Bills --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bills (
  site_id        INTEGER NOT NULL REFERENCES sites(id),
  month_key      CHAR(7) NOT NULL,                    -- "YYYY-MM"
  billed         BIGINT NOT NULL DEFAULT 0,
  penalty        BIGINT NOT NULL DEFAULT 0,
  gst            BIGINT NOT NULL DEFAULT 0,
  tds            BIGINT NOT NULL DEFAULT 0,
  status         TEXT CHECK(status IN ('Submitted','Verified','Approved','Paid','On Hold')),
  payment_mode   TEXT CHECK(payment_mode IN ('Treasury','Self','PFMS','Cheque')),
  remark         VARCHAR(120),
  notesheet_path TEXT,
  submitted_at   TIMESTAMPTZ,
  verified_at    TIMESTAMPTZ,
  approved_at    TIMESTAMPTZ,
  paid_at        TIMESTAMPTZ,
  hold_since     TIMESTAMPTZ,
  updated_by     UUID REFERENCES auth.users(id),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (site_id, month_key)
);

-- 1.5 Flags raised by leadership (VP / CEO) -----------------------------------
CREATE TABLE IF NOT EXISTS bill_flags (
  id          BIGSERIAL PRIMARY KEY,
  site_id     INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  month_key   CHAR(7) NOT NULL,
  note        TEXT    NOT NULL,
  status      TEXT    NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved')),
  raised_by   UUID REFERENCES auth.users(id),
  resolved_by UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS bill_flags_site_month ON bill_flags(site_id, month_key);

-- 1.6 City change requests (raised by leadership, approved by admin) -----------
CREATE TABLE IF NOT EXISTS city_requests (
  id             BIGSERIAL PRIMARY KEY,
  kind           TEXT NOT NULL CHECK (kind IN ('add','delete')),
  city_name      TEXT,
  region         TEXT,
  target_site_id INTEGER REFERENCES sites(id) ON DELETE SET NULL,
  reason         TEXT,
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  requested_by   UUID REFERENCES auth.users(id),
  decided_by     UUID REFERENCES auth.users(id),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  decided_at     TIMESTAMPTZ
);


-- ─────────────────────────────────────────────────────────────────────────────
--  PART 2 — TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────

-- 2.1 Auto-create a profile whenever a user is created (default = site_manager)
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO user_profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email,'@',1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'site_manager'),
    NEW.email
  )
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 2.2 Keep bills.updated_at fresh
CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;
DROP TRIGGER IF EXISTS bills_updated_at ON bills;
CREATE TRIGGER bills_updated_at
  BEFORE UPDATE ON bills
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();


-- ─────────────────────────────────────────────────────────────────────────────
--  PART 3 — STORAGE (notesheet uploads)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('notesheets', 'notesheets', false)
ON CONFLICT (id) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
--  PART 4 — ROW LEVEL SECURITY
--  accounts        → create/edit ALL bills
--  billing_manager → read only assigned sites
--  site_manager    → read only its site
--  leadership      → read all + raise flags + request city changes
--  admin           → everything + manage users + manage cities
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE user_profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites            ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills            ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_flags       ENABLE ROW LEVEL SECURITY;
ALTER TABLE city_requests    ENABLE ROW LEVEL SECURITY;

-- USER PROFILES ---------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_read"          ON user_profiles;
DROP POLICY IF EXISTS "profiles_own_update"    ON user_profiles;
DROP POLICY IF EXISTS "profiles_admin_update"  ON user_profiles;
CREATE POLICY "profiles_read" ON user_profiles
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "profiles_own_update" ON user_profiles
  FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_admin_update" ON user_profiles
  FOR UPDATE USING ((SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin');

-- SITES -----------------------------------------------------------------------
DROP POLICY IF EXISTS "sites_admin"       ON sites;
DROP POLICY IF EXISTS "sites_all_roles"   ON sites;
DROP POLICY IF EXISTS "sites_exec"        ON sites;
DROP POLICY IF EXISTS "sites_admin_write" ON sites;
-- accounts / leadership / admin see every site
CREATE POLICY "sites_all_roles" ON sites FOR SELECT USING (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','accounts','leadership')
);
-- managers see only their assigned sites
CREATE POLICY "sites_exec" ON sites FOR SELECT USING (
  EXISTS (SELECT 1 FROM site_assignments WHERE user_id = auth.uid() AND site_id = sites.id)
);
-- only admin can add / rename / delete cities
CREATE POLICY "sites_admin_write" ON sites FOR ALL
  USING      ((SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin')
  WITH CHECK ((SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin');

-- SITE ASSIGNMENTS ------------------------------------------------------------
DROP POLICY IF EXISTS "assignments_own"          ON site_assignments;
DROP POLICY IF EXISTS "assignments_admin"        ON site_assignments;
DROP POLICY IF EXISTS "assignments_admin_write"  ON site_assignments;
CREATE POLICY "assignments_own" ON site_assignments
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "assignments_admin" ON site_assignments
  FOR SELECT USING ((SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "assignments_admin_write" ON site_assignments FOR ALL
  USING      ((SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin')
  WITH CHECK ((SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin');

-- BILLS -----------------------------------------------------------------------
DROP POLICY IF EXISTS "bills_admin_all"   ON bills;
DROP POLICY IF EXISTS "bills_exec_read"   ON bills;
DROP POLICY IF EXISTS "bills_exec_insert" ON bills;
DROP POLICY IF EXISTS "bills_exec_update" ON bills;
DROP POLICY IF EXISTS "bills_read_all"    ON bills;
DROP POLICY IF EXISTS "bills_write"       ON bills;
-- read: accounts / leadership / admin see all
CREATE POLICY "bills_read_all" ON bills FOR SELECT USING (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','accounts','leadership')
);
-- read: managers see their assigned sites
CREATE POLICY "bills_exec_read" ON bills FOR SELECT USING (
  EXISTS (SELECT 1 FROM site_assignments WHERE user_id = auth.uid() AND site_id = bills.site_id)
);
-- write: ONLY accounts + admin
CREATE POLICY "bills_write" ON bills FOR ALL
  USING      ((SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','accounts'))
  WITH CHECK ((SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','accounts'));

-- FLAGS -----------------------------------------------------------------------
DROP POLICY IF EXISTS "flags_read"   ON bill_flags;
DROP POLICY IF EXISTS "flags_insert" ON bill_flags;
DROP POLICY IF EXISTS "flags_update" ON bill_flags;
CREATE POLICY "flags_read" ON bill_flags
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "flags_insert" ON bill_flags FOR INSERT WITH CHECK (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','leadership')
);
CREATE POLICY "flags_update" ON bill_flags FOR UPDATE USING (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','accounts','leadership')
);

-- CITY REQUESTS ---------------------------------------------------------------
DROP POLICY IF EXISTS "cityreq_read"   ON city_requests;
DROP POLICY IF EXISTS "cityreq_insert" ON city_requests;
DROP POLICY IF EXISTS "cityreq_update" ON city_requests;
CREATE POLICY "cityreq_read" ON city_requests
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "cityreq_insert" ON city_requests FOR INSERT WITH CHECK (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('leadership','admin')
);
CREATE POLICY "cityreq_update" ON city_requests FOR UPDATE USING (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin'
);

-- STORAGE (notesheets) --------------------------------------------------------
DROP POLICY IF EXISTS "notesheet_upload" ON storage.objects;
DROP POLICY IF EXISTS "notesheet_read"   ON storage.objects;
DROP POLICY IF EXISTS "notesheet_update" ON storage.objects;
CREATE POLICY "notesheet_upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'notesheets' AND auth.role() = 'authenticated');
CREATE POLICY "notesheet_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'notesheets' AND auth.role() = 'authenticated');
CREATE POLICY "notesheet_update" ON storage.objects
  FOR UPDATE USING (bucket_id = 'notesheets' AND auth.role() = 'authenticated');


-- ═══════════════════════════════════════════════════════════════════════════
--  DONE. Now do the two manual steps in SETUP.md:
--    STEP B) create the admin user in Authentication → Users
--    STEP C) run the one-line "promote admin" query below (edit the email)
--  After that, the admin logs in and creates every other user + city from the UI.
-- ═══════════════════════════════════════════════════════════════════════════
