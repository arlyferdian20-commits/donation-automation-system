
-- ============================================
-- DONATION AUTOMATION SYSTEM
-- ADMIN AUTHENTICATION & STAFF PROFILES
-- ============================================

-- 1. Create application roles
DO $$
BEGIN
    CREATE TYPE public.app_role AS ENUM (
        'super_admin',
        'fundraising_admin',
        'fundraising_staff',
        'viewer'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;

-- 2. Create staff profiles
CREATE TABLE IF NOT EXISTS public.staff_profiles (
    user_id UUID PRIMARY KEY
        REFERENCES auth.users(id) ON DELETE CASCADE,

    full_name TEXT NOT NULL,

    role public.app_role NOT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_by UUID
        REFERENCES auth.users(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Add index for role filtering
CREATE INDEX IF NOT EXISTS
    idx_staff_profiles_role
ON public.staff_profiles(role);

CREATE INDEX IF NOT EXISTS
    idx_staff_profiles_active
ON public.staff_profiles(is_active);

-- 4. Enable Row Level Security
ALTER TABLE public.staff_profiles
ENABLE ROW LEVEL SECURITY;

-- 5. Remove default/public access
REVOKE ALL ON TABLE public.staff_profiles
FROM PUBLIC, anon, authenticated;

-- 6. Authenticated staff can only read their own profile
GRANT SELECT ON TABLE public.staff_profiles
TO authenticated;

DROP POLICY IF EXISTS
"Staff can read own profile"
ON public.staff_profiles;

CREATE POLICY "Staff can read own profile"
ON public.staff_profiles
FOR SELECT
TO authenticated
USING (
    (SELECT auth.uid()) = user_id
);

-- 7. Backend service access
GRANT ALL ON TABLE public.staff_profiles
TO service_role;

-- 8. Allow authenticated role to use the enum type
GRANT USAGE ON TYPE public.app_role
TO authenticated, service_role;

-- 9. Documentation
COMMENT ON TABLE public.staff_profiles IS
'Profiles and access roles for Donation Automation System staff';

COMMENT ON COLUMN public.staff_profiles.role IS
'Application role: super_admin, fundraising_admin, fundraising_staff, viewer';

COMMENT ON COLUMN public.staff_profiles.is_active IS
'Controls whether the staff account is active in the application';
