-- ============================================
-- DONATION AUTOMATION SYSTEM
-- DATA DONATIONS MODULE (READ API)
-- ============================================
-- Prerequisites:
-- - public.donations, public.donors, public.campaigns exist.
-- - RBAC policies and public.current_staff_role() are installed.
--
-- This migration adds a paginated, searchable read endpoint for the
-- authenticated fundraising workspace. It does not change payment status.
-- It runs as SECURITY INVOKER so existing table grants and RLS policies
-- remain in force.

-- 1. Support newest-first transaction listing.
CREATE INDEX IF NOT EXISTS idx_donations_created_at
ON public.donations (created_at DESC);

-- 2. Return one page of donations plus total count.
CREATE OR REPLACE FUNCTION public.get_donations_page(
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_campaign_id UUID DEFAULT NULL,
    p_from TIMESTAMPTZ DEFAULT NULL,
    p_to TIMESTAMPTZ DEFAULT NULL,
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_role TEXT;
    v_page INTEGER := GREATEST(COALESCE(p_page, 1), 1);
    v_page_size INTEGER := LEAST(GREATEST(COALESCE(p_page_size, 20), 1), 100);
    v_offset INTEGER;
    v_total BIGINT;
    v_rows JSONB;
    v_search TEXT := NULLIF(BTRIM(p_search), '');
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    v_role := public.current_staff_role();

    IF COALESCE(v_role, '') NOT IN (
        'super_admin',
        'fundraising_admin',
        'fundraising_staff'
    ) THEN
        RAISE EXCEPTION 'You do not have permission to view donation transactions'
            USING ERRCODE = '42501';
    END IF;

    IF p_from IS NOT NULL AND p_to IS NOT NULL AND p_from > p_to THEN
        RAISE EXCEPTION 'Invalid date range: p_from must be before p_to'
            USING ERRCODE = '22023';
    END IF;

    v_offset := (v_page - 1) * v_page_size;

    SELECT COUNT(*)
    INTO v_total
    FROM public.donations AS d
    LEFT JOIN public.donors AS donor
        ON donor.id = d.donor_id
    WHERE
        (p_status IS NULL OR d.payment_status = p_status)
        AND (p_campaign_id IS NULL OR d.campaign_id = p_campaign_id)
        AND (p_from IS NULL OR d.created_at >= p_from)
        AND (p_to IS NULL OR d.created_at <= p_to)
        AND (
            v_search IS NULL
            OR d.transaction_code ILIKE '%' || v_search || '%'
            OR donor.full_name ILIKE '%' || v_search || '%'
            OR COALESCE(donor.phone_number, '') ILIKE '%' || v_search || '%'
            OR COALESCE(donor.email, '') ILIKE '%' || v_search || '%'
        );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', page_rows.id,
                'transaction_code', page_rows.transaction_code,
                'amount', page_rows.amount,
                'payment_status', page_rows.payment_status,
                'payment_method', page_rows.payment_method,
                'created_at', page_rows.created_at,
                'donor', CASE
                    WHEN page_rows.donor_id IS NULL THEN NULL
                    ELSE jsonb_build_object(
                        'id', page_rows.donor_id,
                        'full_name', page_rows.donor_name,
                        'phone_number', page_rows.donor_phone,
                        'email', page_rows.donor_email
                    )
                END,
                'campaign', CASE
                    WHEN page_rows.campaign_id IS NULL THEN NULL
                    ELSE jsonb_build_object(
                        'id', page_rows.campaign_id,
                        'campaign_name', page_rows.campaign_name
                    )
                END
            )
            ORDER BY page_rows.created_at DESC, page_rows.id DESC
        ),
        '[]'::jsonb
    )
    INTO v_rows
    FROM (
        SELECT
            d.id,
            d.donor_id,
            d.campaign_id,
            d.transaction_code,
            d.amount,
            d.payment_status,
            d.payment_method,
            d.created_at,
            donor.full_name AS donor_name,
            donor.phone_number AS donor_phone,
            donor.email AS donor_email,
            campaign.campaign_name
        FROM public.donations AS d
        LEFT JOIN public.donors AS donor
            ON donor.id = d.donor_id
        LEFT JOIN public.campaigns AS campaign
            ON campaign.id = d.campaign_id
        WHERE
            (p_status IS NULL OR d.payment_status = p_status)
            AND (p_campaign_id IS NULL OR d.campaign_id = p_campaign_id)
            AND (p_from IS NULL OR d.created_at >= p_from)
            AND (p_to IS NULL OR d.created_at <= p_to)
            AND (
                v_search IS NULL
                OR d.transaction_code ILIKE '%' || v_search || '%'
                OR donor.full_name ILIKE '%' || v_search || '%'
                OR COALESCE(donor.phone_number, '') ILIKE '%' || v_search || '%'
                OR COALESCE(donor.email, '') ILIKE '%' || v_search || '%'
            )
        ORDER BY d.created_at DESC, d.id DESC
        LIMIT v_page_size
        OFFSET v_offset
    ) AS page_rows;

    RETURN jsonb_build_object(
        'data', v_rows,
        'total', v_total,
        'page', v_page,
        'page_size', v_page_size,
        'total_pages', CEIL(v_total::NUMERIC / v_page_size),
        'generated_at', NOW()
    );
END;
$$;

-- 3. Expose this RPC only to signed-in users.
REVOKE ALL
ON FUNCTION public.get_donations_page(TEXT, TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.get_donations_page(TEXT, TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER)
TO authenticated, service_role;

COMMENT ON FUNCTION public.get_donations_page(TEXT, TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER) IS
'Paginated and searchable donation transaction list for active fundraising staff. Uses SECURITY INVOKER and existing RLS policies.';
