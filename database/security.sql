
-- Donation Automation System
-- Database Security Configuration
-- Apply AFTER schema.sql

-- 1. Enable Row Level Security
ALTER TABLE public.donors
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.campaigns
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.donations
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment_logs
ENABLE ROW LEVEL SECURITY;


-- 2. Remove direct access from public roles
REVOKE ALL ON TABLE
    public.donors,
    public.campaigns,
    public.donations,
    public.payment_logs
FROM PUBLIC, anon, authenticated;


-- 3. Grant backend access to service_role
GRANT ALL ON TABLE
    public.donors,
    public.campaigns,
    public.donations,
    public.payment_logs
TO service_role;


-- 4. No public policies are created.
-- Access is denied by default for anon and authenticated.
-- Backend operations must use protected server-side credentials.
