-- ============================================
-- DONATION AUTOMATION SYSTEM
-- DATA API SCHEMA ACCESS
-- ============================================
--
-- Apply after the table grants and RLS policies in security.sql / RBAC setup.
--
-- PostgreSQL grants and RLS policies are separate controls:
-- - USAGE allows an authenticated client to resolve objects in public.
-- - Table/column grants determine which operations are available.
-- - RLS policies determine which rows the signed-in staff member can access.
--
-- Keep anonymous browser access disabled.
GRANT USAGE ON SCHEMA public TO authenticated;
REVOKE USAGE ON SCHEMA public FROM anon;

-- Do not grant broad table privileges here.
-- Existing RBAC grants and RLS policies remain responsible for table access.
-- Never expose service_role or a secret key in browser code.
