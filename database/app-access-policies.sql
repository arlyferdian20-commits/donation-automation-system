-- ============================================
-- DONATION AUTOMATION SYSTEM
-- APPLICATION ACCESS POLICIES (RBAC)
-- ============================================
--
-- Apply AFTER:
--   1. database/schema.sql
--   2. database/security.sql
--   3. database/admin-auth.sql
--   4. database/auth-hook.sql
--
-- Role claims are issued by the trusted Custom Access Token Hook:
--   app_role, staff_active
--
-- IMPORTANT:
-- - Never expose service_role / secret API keys in the browser.
-- - Payment status is controlled by trusted backend/webhook only.
-- - Campaigns are archived by changing status; do not hard-delete.
-- - Staff profile creation/role changes must use a trusted backend.
--

-- 1. Keep authorization helper functions executable only by signed-in users.
REVOKE ALL ON FUNCTION public.current_staff_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_staff_role(text[]) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.current_staff_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_staff_role(text[]) TO authenticated;

-- 2. Ensure RLS remains enabled.
ALTER TABLE public.donors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;

-- 3. Remove broad table privileges before granting the minimum required.
REVOKE ALL ON TABLE
    public.donors,
    public.campaigns,
    public.donations,
    public.payment_logs,
    public.staff_profiles
FROM PUBLIC, anon, authenticated;

-- 4. Remove previous RBAC policies so this script is safe to re-run.
DROP POLICY IF EXISTS "RBAC authorized staff can read donors" ON public.donors;
DROP POLICY IF EXISTS "RBAC staff can read donors" ON public.donors;
DROP POLICY IF EXISTS "RBAC operational staff can create donors" ON public.donors;

DROP POLICY IF EXISTS "RBAC staff can read campaigns" ON public.campaigns;
DROP POLICY IF EXISTS "RBAC campaign admins can create campaigns" ON public.campaigns;
DROP POLICY IF EXISTS "RBAC campaign admins can update campaigns" ON public.campaigns;
DROP POLICY IF EXISTS "RBAC campaign admins can delete campaigns" ON public.campaigns;

DROP POLICY IF EXISTS "RBAC fundraising staff can read donations" ON public.donations;
DROP POLICY IF EXISTS "RBAC operational staff can create donations" ON public.donations;
DROP POLICY IF EXISTS "RBAC fundraising staff can update donation payment fields" ON public.donations;

DROP POLICY IF EXISTS "RBAC fundraising admins can read payment logs" ON public.payment_logs;

DROP POLICY IF EXISTS "RBAC staff can read own profile" ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can create staff profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can delete staff profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can read all staff profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can update staff profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "Staff can read own profile" ON public.staff_profiles;

-- Keep the Custom Access Token Hook's read policy intact:
-- "Supabase Auth can read staff profiles" for supabase_auth_admin.

-- 5. Grant minimum table/column privileges.
GRANT USAGE ON SCHEMA public TO authenticated;

-- Campaigns: all active staff can read; admins can create and edit.
GRANT SELECT ON TABLE public.campaigns TO authenticated;
GRANT INSERT (campaign_name, description, target_amount, status)
    ON TABLE public.campaigns TO authenticated;
GRANT UPDATE (campaign_name, description, target_amount, status)
    ON TABLE public.campaigns TO authenticated;

-- Donors: operational fundraising roles can read and add donor records.
GRANT SELECT ON TABLE public.donors TO authenticated;
GRANT INSERT (full_name, phone_number, email)
    ON TABLE public.donors TO authenticated;

-- Donations: operational roles can read and create pending transactions.
-- payment_status, transaction_code, amount, and timestamps cannot be
-- changed through an UPDATE from the browser. payment_status is omitted
-- from INSERT privileges so its database default remains 'pending'.
GRANT SELECT ON TABLE public.donations TO authenticated;
GRANT INSERT (donor_id, campaign_id, transaction_code, amount, payment_method)
    ON TABLE public.donations TO authenticated;

-- Payment logs contain raw provider payloads; keep them backend-only.
-- staff_profiles are read-only from the browser. Provisioning and role
-- changes must be performed by a trusted server-side process.
GRANT SELECT ON TABLE public.staff_profiles TO authenticated;

-- 6. Donor policies.
CREATE POLICY "RBAC staff can read donors"
ON public.donors
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin', 'fundraising_staff']
    ))
);

CREATE POLICY "RBAC operational staff can create donors"
ON public.donors
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin', 'fundraising_staff']
    ))
);

-- 7. Campaign policies.
CREATE POLICY "RBAC staff can read campaigns"
ON public.campaigns
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin', 'fundraising_staff', 'viewer']
    ))
);

CREATE POLICY "RBAC campaign admins can create campaigns"
ON public.campaigns
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']
    ))
);

CREATE POLICY "RBAC campaign admins can update campaigns"
ON public.campaigns
FOR UPDATE
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']
    ))
)
WITH CHECK (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']
    ))
);

-- No DELETE policy: archive campaigns by updating status instead.

-- 8. Donation policies.
CREATE POLICY "RBAC fundraising staff can read donations"
ON public.donations
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin', 'fundraising_staff']
    ))
);

CREATE POLICY "RBAC operational staff can create donations"
ON public.donations
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin', 'fundraising_staff']
    ))
);

-- No UPDATE or DELETE policy for browser users.
-- Payment confirmation and correction must go through a trusted backend.

-- 9. Payment logs intentionally have no authenticated grants or policies.
-- service_role remains the backend integration role.

-- 10. Staff profiles: users can read their own profile; super admins can
-- read all profiles. No browser-side INSERT/UPDATE/DELETE is granted.
CREATE POLICY "RBAC staff can read own profile"
ON public.staff_profiles
FOR SELECT
TO authenticated
USING (
    (SELECT auth.uid()) = user_id
);

CREATE POLICY "RBAC super admins can read all staff profiles"
ON public.staff_profiles
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(ARRAY['super_admin']))
);

-- 11. Keep backend service access.
GRANT ALL ON TABLE
    public.donors,
    public.campaigns,
    public.donations,
    public.payment_logs,
    public.staff_profiles
TO service_role;

-- 12. Documentation.
COMMENT ON TABLE public.payment_logs IS
'Raw payment provider event logs. Backend/service_role access only; do not expose raw payloads to browser clients.';

COMMENT ON TABLE public.staff_profiles IS
'Staff roles and activation status. Browser users may read authorized profiles only; account provisioning and role changes are server-side.';
