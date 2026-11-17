-- ============================================
-- DONATION AUTOMATION SYSTEM
-- ROLE-BASED ACCESS CONTROL (RBAC)
-- ============================================
--
-- Prerequisites:
--   1. database/schema.sql
--   2. database/security.sql
--   3. database/admin-auth.sql
--   4. database/auth-hook.sql
--
-- IMPORTANT:
-- - This file configures database permissions and RLS policies.
-- - It does not create staff accounts or assign roles.
-- - Role claims come from the trusted Custom Access Token Hook.
-- - After role changes, users must refresh their auth session/token.
-- - Backend integrations should continue using protected service_role
--   credentials only on trusted servers. Never expose service_role keys.
--
-- Initial access matrix:
--   super_admin:
--     Full staff-profile administration; read donors, campaigns,
--     donations and payment logs; manage campaigns; update payment status.
--   fundraising_admin:
--     Read donors, campaigns, donations and payment logs;
--     manage campaigns; update payment status.
--   fundraising_staff:
--     Read campaigns and donations; update payment status/method only.
--   viewer:
--     Read campaigns only at this stage. A separate, sanitized reporting
--     view will be added before exposing aggregate reports to viewers.
--
-- Donor data and raw payment event payloads are intentionally not
-- exposed to the viewer role. Donor creation, donation creation and
-- payment-log insertion remain backend-only operations.

-- 1. Helper: read the trusted role claim from the JWT.
-- Inactive or unprovisioned staff receive no application role.
CREATE OR REPLACE FUNCTION public.current_staff_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SET search_path = ''
AS $function$
    SELECT CASE
        WHEN COALESCE(
            (SELECT auth.jwt() ->> 'staff_active'),
            'false'
        ) = 'true'
        THEN (SELECT auth.jwt() ->> 'app_role')
        ELSE NULL
    END;
$function$;

-- 2. Helper: check whether the current user has one of the allowed roles.
CREATE OR REPLACE FUNCTION public.has_staff_role(allowed_roles TEXT[])
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = ''
AS $function$
    SELECT COALESCE(
        public.current_staff_role() = ANY (allowed_roles),
        FALSE
    );
$function$;

-- Only authenticated application users may call these helpers.
REVOKE ALL ON FUNCTION public.current_staff_role()
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION public.has_staff_role(TEXT[])
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.current_staff_role()
TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.has_staff_role(TEXT[])
TO authenticated, service_role;


-- 3. Ensure RLS is enabled on all application tables.
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_logs ENABLE ROW LEVEL SECURITY;


-- 4. Reset application-role policies created by this script.
DROP POLICY IF EXISTS "RBAC staff can read own profile"
ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can read all staff profiles"
ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can create staff profiles"
ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can update staff profiles"
ON public.staff_profiles;
DROP POLICY IF EXISTS "RBAC super admins can delete staff profiles"
ON public.staff_profiles;

DROP POLICY IF EXISTS "RBAC authorized staff can read donors"
ON public.donors;

DROP POLICY IF EXISTS "RBAC staff can read campaigns"
ON public.campaigns;
DROP POLICY IF EXISTS "RBAC campaign admins can create campaigns"
ON public.campaigns;
DROP POLICY IF EXISTS "RBAC campaign admins can update campaigns"
ON public.campaigns;
DROP POLICY IF EXISTS "RBAC campaign admins can delete campaigns"
ON public.campaigns;

DROP POLICY IF EXISTS "RBAC fundraising staff can read donations"
ON public.donations;
DROP POLICY IF EXISTS "RBAC fundraising staff can update donation payment fields"
ON public.donations;

DROP POLICY IF EXISTS "RBAC fundraising admins can read payment logs"
ON public.payment_logs;


-- 5. Remove broad direct privileges, then grant minimum required access.
REVOKE ALL ON TABLE
    public.staff_profiles,
    public.donors,
    public.campaigns,
    public.donations,
    public.payment_logs
FROM PUBLIC, anon, authenticated;

-- Staff can read their own profile; super admins can manage staff.
GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.staff_profiles
TO authenticated;

-- Donor records are sensitive; only fundraising admins and super admins
-- can read them directly. Donor creation remains backend-only.
GRANT SELECT ON TABLE public.donors TO authenticated;

-- All active staff can read campaign information.
-- Only fundraising admins and super admins can manage campaigns.
GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.campaigns
TO authenticated;

-- Fundraising team can read donations. Restrict updates to payment fields.
GRANT SELECT ON TABLE public.donations TO authenticated;
REVOKE UPDATE ON TABLE public.donations FROM authenticated;
GRANT UPDATE (payment_status, payment_method)
ON TABLE public.donations
TO authenticated;

-- Raw payment logs can contain sensitive provider payloads.
-- Only fundraising admins and super admins can read them.
GRANT SELECT ON TABLE public.payment_logs TO authenticated;

-- Ensure trusted backend access remains available.
GRANT ALL ON TABLE
    public.staff_profiles,
    public.donors,
    public.campaigns,
    public.donations,
    public.payment_logs
TO service_role;


-- 6. Staff profile policies.
-- Staff can read their own profile.
CREATE POLICY "RBAC staff can read own profile"
ON public.staff_profiles
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);

-- Super admins can read all staff profiles.
CREATE POLICY "RBAC super admins can read all staff profiles"
ON public.staff_profiles
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(ARRAY['super_admin']::TEXT[]))
);

-- Only super admins can create staff profiles and assign roles.
CREATE POLICY "RBAC super admins can create staff profiles"
ON public.staff_profiles
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT public.has_staff_role(ARRAY['super_admin']::TEXT[]))
);

-- Only super admins can change staff details, roles and active status.
CREATE POLICY "RBAC super admins can update staff profiles"
ON public.staff_profiles
FOR UPDATE
TO authenticated
USING (
    (SELECT public.has_staff_role(ARRAY['super_admin']::TEXT[]))
)
WITH CHECK (
    (SELECT public.has_staff_role(ARRAY['super_admin']::TEXT[]))
);

CREATE POLICY "RBAC super admins can delete staff profiles"
ON public.staff_profiles
FOR DELETE
TO authenticated
USING (
    (SELECT public.has_staff_role(ARRAY['super_admin']::TEXT[]))
);


-- 7. Donor policies.
CREATE POLICY "RBAC authorized staff can read donors"
ON public.donors
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']::TEXT[]
    ))
);


-- 8. Campaign policies.
CREATE POLICY "RBAC staff can read campaigns"
ON public.campaigns
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY[
            'super_admin',
            'fundraising_admin',
            'fundraising_staff',
            'viewer'
        ]::TEXT[]
    ))
);

CREATE POLICY "RBAC campaign admins can create campaigns"
ON public.campaigns
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']::TEXT[]
    ))
);

CREATE POLICY "RBAC campaign admins can update campaigns"
ON public.campaigns
FOR UPDATE
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']::TEXT[]
    ))
)
WITH CHECK (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']::TEXT[]
    ))
);

CREATE POLICY "RBAC campaign admins can delete campaigns"
ON public.campaigns
FOR DELETE
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']::TEXT[]
    ))
);


-- 9. Donation policies.
CREATE POLICY "RBAC fundraising staff can read donations"
ON public.donations
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY[
            'super_admin',
            'fundraising_admin',
            'fundraising_staff'
        ]::TEXT[]
    ))
);

-- Column-level GRANT above limits changes to payment_status/payment_method.
CREATE POLICY "RBAC fundraising staff can update donation payment fields"
ON public.donations
FOR UPDATE
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY[
            'super_admin',
            'fundraising_admin',
            'fundraising_staff'
        ]::TEXT[]
    ))
)
WITH CHECK (
    (SELECT public.has_staff_role(
        ARRAY[
            'super_admin',
            'fundraising_admin',
            'fundraising_staff'
        ]::TEXT[]
    ))
);


-- 10. Payment log policies.
CREATE POLICY "RBAC fundraising admins can read payment logs"
ON public.payment_logs
FOR SELECT
TO authenticated
USING (
    (SELECT public.has_staff_role(
        ARRAY['super_admin', 'fundraising_admin']::TEXT[]
    ))
);


-- 11. Documentation.
COMMENT ON FUNCTION public.current_staff_role() IS
'Returns the trusted app_role JWT claim only when staff_active is true.';

COMMENT ON FUNCTION public.has_staff_role(TEXT[]) IS
'Checks whether the authenticated JWT has one of the supplied active staff roles.';

COMMENT ON TABLE public.staff_profiles IS
'Staff profiles and trusted application roles. Role changes are restricted to super admins and trusted backend operations.';

-- END OF RBAC CONFIGURATION
