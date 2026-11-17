-- ============================================
-- DONATION AUTOMATION SYSTEM
-- SUPABASE CUSTOM ACCESS TOKEN HOOK
-- ============================================
--
-- Purpose:
-- Add trusted staff role claims to the JWT issued by Supabase Auth.
-- The source of truth is public.staff_profiles, never user_metadata.
--
-- Claims added:
--   app_role     : super_admin | fundraising_admin |
--                  fundraising_staff | viewer | null
--   staff_active : true | false
--
-- IMPORTANT:
-- 1. This file creates the function and its database permissions.
-- 2. It does NOT enable the hook in Supabase Dashboard.
-- 3. Do not expose service_role or database credentials to clients.
--

-- 1. Allow Supabase Auth to read staff profiles.
-- RLS remains enabled. This policy is restricted to supabase_auth_admin.
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT USAGE ON TYPE public.app_role TO supabase_auth_admin;
GRANT SELECT ON TABLE public.staff_profiles TO supabase_auth_admin;

DROP POLICY IF EXISTS
    "Supabase Auth can read staff profiles"
ON public.staff_profiles;

CREATE POLICY "Supabase Auth can read staff profiles"
ON public.staff_profiles
FOR SELECT
TO supabase_auth_admin
USING (true);

-- 2. Create the Custom Access Token Hook.
-- SECURITY INVOKER is intentional: permissions are granted explicitly
-- to supabase_auth_admin, without SECURITY DEFINER privileges.
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
    claims jsonb;
    staff_role public.app_role;
    staff_is_active boolean;
BEGIN
    claims := COALESCE(event -> 'claims', '{}'::jsonb);

    SELECT
        sp.role,
        sp.is_active
    INTO
        staff_role,
        staff_is_active
    FROM public.staff_profiles AS sp
    WHERE sp.user_id = (event ->> 'user_id')::uuid;

    IF FOUND AND staff_is_active IS TRUE THEN
        claims := jsonb_set(
            claims,
            '{app_role}',
            to_jsonb(staff_role),
            true
        );

        claims := jsonb_set(
            claims,
            '{staff_active}',
            'true'::jsonb,
            true
        );
    ELSE
        -- A missing or inactive staff profile receives no application role.
        claims := jsonb_set(
            claims,
            '{app_role}',
            'null'::jsonb,
            true
        );

        claims := jsonb_set(
            claims,
            '{staff_active}',
            'false'::jsonb,
            true
        );
    END IF;

    -- Supabase Custom Access Token Hook expects an object containing claims.
    RETURN jsonb_build_object('claims', claims);
END;
$$;

-- 3. Restrict function execution to Supabase Auth only.
REVOKE EXECUTE
ON FUNCTION public.custom_access_token_hook(jsonb)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.custom_access_token_hook(jsonb)
TO supabase_auth_admin;

-- 4. Documentation.
COMMENT ON FUNCTION public.custom_access_token_hook(jsonb) IS
'Adds trusted app_role and staff_active claims from public.staff_profiles to Supabase Auth access tokens.';

