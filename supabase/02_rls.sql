-- WeVois Billing — Row Level Security
-- Run AFTER 01_schema.sql in Supabase SQL Editor

-- ── Admin Helper Function (SECURITY DEFINER bypasses RLS to prevent recursion)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Enable RLS on all tables
ALTER TABLE user_profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites             ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_assignments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills             ENABLE ROW LEVEL SECURITY;


-- ── user_profiles ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_read" ON user_profiles;
CREATE POLICY "profiles_read" ON user_profiles
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "profiles_own_update" ON user_profiles;
CREATE POLICY "profiles_own_update" ON user_profiles
  FOR UPDATE USING (id = auth.uid());

DROP POLICY IF EXISTS "profiles_admin_all" ON user_profiles;
DROP POLICY IF EXISTS "profiles_admin_upsert" ON user_profiles;
CREATE POLICY "profiles_admin_all" ON user_profiles
  FOR ALL USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── sites ─────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sites_admin" ON sites;
DROP POLICY IF EXISTS "sites_exec" ON sites;
DROP POLICY IF EXISTS "sites_admin_all" ON sites;
DROP POLICY IF EXISTS "sites_read_authenticated" ON sites;
DROP POLICY IF EXISTS "sites_read_scoped" ON sites;

CREATE POLICY "sites_read_scoped" ON sites
  FOR SELECT USING (
    public.is_admin() OR
    EXISTS (
      SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('leadership','admin')
    ) OR
    EXISTS (
      SELECT 1 FROM site_assignments
      WHERE user_id = auth.uid() AND site_id = sites.id
    )
  );

CREATE POLICY "sites_admin_all" ON sites
  FOR ALL USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── site_assignments ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "assignments_own" ON site_assignments;
DROP POLICY IF EXISTS "assignments_admin" ON site_assignments;
DROP POLICY IF EXISTS "assignments_admin_all" ON site_assignments;

CREATE POLICY "assignments_read" ON site_assignments
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "assignments_admin_all" ON site_assignments
  FOR ALL USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── bills ─────────────────────────────────────────────────────────────────────
ALTER TABLE bills DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bills_admin_all" ON bills;
DROP POLICY IF EXISTS "bills_exec_read" ON bills;
DROP POLICY IF EXISTS "bills_exec_insert" ON bills;
DROP POLICY IF EXISTS "bills_exec_update" ON bills;
DROP POLICY IF EXISTS "bills_all_access" ON bills;

CREATE POLICY "bills_all_access" ON bills
  FOR ALL USING (true) WITH CHECK (true);


-- ── Storage (notesheets bucket) ───────────────────────────────────────────────
DROP POLICY IF EXISTS "notesheet_upload" ON storage.objects;
CREATE POLICY "notesheet_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'notesheets' AND auth.role() = 'authenticated'
  );

DROP POLICY IF EXISTS "notesheet_read" ON storage.objects;
CREATE POLICY "notesheet_read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'notesheets' AND auth.role() = 'authenticated'
  );

DROP POLICY IF EXISTS "notesheet_update" ON storage.objects;
CREATE POLICY "notesheet_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'notesheets' AND auth.role() = 'authenticated'
  );
