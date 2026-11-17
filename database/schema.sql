
-- Donation Automation System
-- Initial PostgreSQL Database Schema

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Donors
CREATE TABLE IF NOT EXISTS public.donors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    phone_number TEXT,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Campaigns
CREATE TABLE IF NOT EXISTS public.campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_name TEXT NOT NULL,
    description TEXT,
    target_amount NUMERIC(15,2) DEFAULT 0,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Donations
CREATE TABLE IF NOT EXISTS public.donations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES public.donors(id),
    campaign_id UUID REFERENCES public.campaigns(id),
    transaction_code TEXT UNIQUE NOT NULL,
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    payment_status TEXT DEFAULT 'pending',
    payment_method TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Payment Logs
CREATE TABLE IF NOT EXISTS public.payment_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donation_id UUID REFERENCES public.donations(id),
    event_type TEXT NOT NULL,
    event_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_donations_donor
ON public.donations(donor_id);

CREATE INDEX IF NOT EXISTS idx_donations_campaign
ON public.donations(campaign_id);

CREATE INDEX IF NOT EXISTS idx_donations_status
ON public.donations(payment_status);

CREATE INDEX IF NOT EXISTS idx_payment_logs_donation
ON public.payment_logs(donation_id);
