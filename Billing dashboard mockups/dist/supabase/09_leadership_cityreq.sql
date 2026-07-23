-- WeVois Billing — let LEADERSHIP (VP/CEO) approve city requests + apply them
-- Run AFTER 06_cities.sql. Extends approval rights from admin-only to admin+leadership.

-- Leadership can now approve/reject city change requests
DROP POLICY IF EXISTS "cityreq_update" ON city_requests;
CREATE POLICY "cityreq_update" ON city_requests FOR UPDATE USING (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','leadership')
);

-- ...and actually add/delete the city when they approve
DROP POLICY IF EXISTS "sites_admin_write" ON sites;
CREATE POLICY "sites_admin_write" ON sites FOR ALL
  USING      ((SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','leadership'))
  WITH CHECK ((SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('admin','leadership'));
