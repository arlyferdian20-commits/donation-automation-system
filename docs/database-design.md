
# Database Design

## 1. Overview

This document describes the proposed database structure for the Donation Automation System using Supabase and PostgreSQL.

The database is designed to manage donors, donation transactions, fundraising campaigns, and payment records.

## 2. Proposed Database Tables

### A. donors

Stores donor information.

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| full_name | TEXT | Donor name |
| phone_number | TEXT | WhatsApp number |
| email | TEXT | Email address |
| created_at | TIMESTAMPTZ | Registration date |

### B. campaigns

Stores fundraising campaign information.

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| campaign_name | TEXT | Campaign title |
| description | TEXT | Campaign description |
| target_amount | NUMERIC | Fundraising target |
| status | TEXT | Campaign status |
| created_at | TIMESTAMPTZ | Creation date |

### C. donations

Stores donation transactions.

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| donor_id | UUID | Reference to donors |
| campaign_id | UUID | Reference to campaigns |
| transaction_code | TEXT | Unique transaction ID |
| amount | NUMERIC | Donation amount |
| payment_status | TEXT | Payment status |
| payment_method | TEXT | Payment method |
| created_at | TIMESTAMPTZ | Transaction date |

### D. payment_logs

Stores payment processing events.

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| donation_id | UUID | Reference to donations |
| event_type | TEXT | Payment event |
| event_payload | JSONB | Event data |
| created_at | TIMESTAMPTZ | Event timestamp |

## 3. Database Relationships

- One donor can have multiple donations.
- One campaign can receive multiple donations.
- One donation can have multiple payment logs.

## 4. Data Security

- Use Supabase Row Level Security (RLS).
- Protect donor personal information.
- Restrict access based on user roles.
- Never expose service role keys.
- Validate payment events before updating donation status.

## 5. Data Integrity

- Use UUID primary keys.
- Enforce unique transaction codes.
- Use foreign key constraints.
- Validate donation amounts.
- Maintain transaction history.

## 6. Development Status

This is a proposed database schema. SQL migrations, database relationships, security policies, and application integrations will be implemented and tested incrementally.
