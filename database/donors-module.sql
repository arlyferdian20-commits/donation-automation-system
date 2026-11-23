-- ============================================
-- DONATION AUTOMATION SYSTEM
-- DATA DONORS MODULE (READ API)
-- ============================================
-- Paginated donor directory with paid donation totals.
-- SECURITY INVOKER preserves table grants and RLS.

CREATE INDEX IF NOT EXISTS idx_donors_created_at
ON public.donors (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_donations_donor_status_created
ON public.donations (donor_id, payment_status, created_at DESC);

CREATE OR REPLACE FUNCTION public.get_donors_page(
    p_search TEXT DEFAULT NULL,
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
        RAISE EXCEPTION 'You do not have permission to view donor records'
            USING ERRCODE = '42501';
    END IF;

    v_offset := (v_page - 1) * v_page_size;

    SELECT COUNT(*)
    INTO v_total
    FROM public.donors AS donor
    WHERE
        v_search IS NULL
        OR donor.full_name ILIKE '%' || v_search || '%'
        OR COALESCE(donor.phone_number, '') ILIKE '%' || v_search || '%'
        OR COALESCE(donor.email, '') ILIKE '%' || v_search || '%';

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', page_rows.id,
                'full_name', page_rows.full_name,
                'phone_number', page_rows.phone_number,
                'email', page_rows.email,
                'created_at', page_rows.created_at,
                'total_donated', page_rows.total_donated,
                'paid_transaction_count', page_rows.paid_transaction_count,
                'total_transaction_count', page_rows.total_transaction_count,
                'last_donation_at', page_rows.last_donation_at
            )
            ORDER BY page_rows.created_at DESC, page_rows.id DESC
        ),
        '[]'::jsonb
    )
    INTO v_rows
    FROM (
        SELECT
            donor.id,
            donor.full_name,
            donor.phone_number,
            donor.email,
            donor.created_at,
            COALESCE(stats.total_donated, 0) AS total_donated,
            COALESCE(stats.paid_transaction_count, 0) AS paid_transaction_count,
            COALESCE(stats.total_transaction_count, 0) AS total_transaction_count,
            stats.last_donation_at
        FROM public.donors AS donor
        LEFT JOIN LATERAL (
            SELECT
                SUM(d.amount) FILTER (WHERE d.payment_status = 'paid') AS total_donated,
                COUNT(*) FILTER (WHERE d.payment_status = 'paid') AS paid_transaction_count,
                COUNT(*) AS total_transaction_count,
                MAX(d.created_at) AS last_donation_at
            FROM public.donations AS d
            WHERE d.donor_id = donor.id
        ) AS stats ON TRUE
        WHERE
            v_search IS NULL
            OR donor.full_name ILIKE '%' || v_search || '%'
            OR COALESCE(donor.phone_number, '') ILIKE '%' || v_search || '%'
            OR COALESCE(donor.email, '') ILIKE '%' || v_search || '%'
        ORDER BY donor.created_at DESC, donor.id DESC
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

REVOKE ALL
ON FUNCTION public.get_donors_page(TEXT, INTEGER, INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.get_donors_page(TEXT, INTEGER, INTEGER)
TO authenticated, service_role;

COMMENT ON FUNCTION public.get_donors_page(TEXT, INTEGER, INTEGER) IS
'Paginated searchable donor directory for active fundraising staff. Total donated and paid transaction count include only donations with payment_status=paid. Uses SECURITY INVOKER and existing RLS policies.';
