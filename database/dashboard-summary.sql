-- ============================================
-- DONATION AUTOMATION SYSTEM
-- DASHBOARD SUMMARY RPC
-- ============================================
--
-- Returns aggregate metrics for active staff.
-- Recent transaction summaries exclude donor personal data.
-- Viewer receives aggregates only.
--
-- SECURITY DEFINER is narrowly scoped to this function so it can
-- aggregate data without granting direct table access to viewers.
-- The caller is checked against the live staff_profiles row and
-- trusted JWT claims on every call.
--

CREATE OR REPLACE FUNCTION public.get_dashboard_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_role text;
    v_summary jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    SELECT sp.role::text
    INTO v_role
    FROM public.staff_profiles AS sp
    WHERE sp.user_id = auth.uid()
      AND sp.is_active IS TRUE;

    IF v_role IS NULL
       OR COALESCE(auth.jwt() ->> 'staff_active', 'false') <> 'true'
       OR auth.jwt() ->> 'app_role' IS DISTINCT FROM v_role
    THEN
        RAISE EXCEPTION 'Active staff access required'
            USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_build_object(
        'total_amount_recorded',
            COALESCE((SELECT SUM(d.amount) FROM public.donations AS d), 0),
        'total_transactions',
            (SELECT COUNT(*) FROM public.donations AS d),
        'active_campaigns',
            (
                SELECT COUNT(*)
                FROM public.campaigns AS c
                WHERE c.status = 'active'
            ),
        'total_donors',
            (SELECT COUNT(*) FROM public.donors AS d),
        'recent_donations',
            CASE
                WHEN v_role IN (
                    'super_admin',
                    'fundraising_admin',
                    'fundraising_staff'
                )
                THEN COALESCE(
                    (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'transaction_code', recent.transaction_code,
                                'amount', recent.amount,
                                'payment_status', recent.payment_status,
                                'created_at', recent.created_at,
                                'campaign_name', recent.campaign_name
                            )
                            ORDER BY recent.created_at DESC
                        )
                        FROM (
                            SELECT
                                d.transaction_code,
                                d.amount,
                                d.payment_status,
                                d.created_at,
                                c.campaign_name
                            FROM public.donations AS d
                            LEFT JOIN public.campaigns AS c
                                ON c.id = d.campaign_id
                            ORDER BY d.created_at DESC
                            LIMIT 5
                        ) AS recent
                    ),
                    '[]'::jsonb
                )
                ELSE '[]'::jsonb
            END,
        'generated_at', NOW()
    )
    INTO v_summary;

    RETURN v_summary;
END;
$$;

REVOKE ALL
ON FUNCTION public.get_dashboard_summary()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.get_dashboard_summary()
TO authenticated;

COMMENT ON FUNCTION public.get_dashboard_summary() IS
'Returns aggregate dashboard metrics for active staff. Recent transaction summaries are included only for operational roles and exclude donor personal data.';
