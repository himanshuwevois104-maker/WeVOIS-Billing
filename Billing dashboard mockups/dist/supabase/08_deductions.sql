-- WeVois Billing — add GST + TDS deduction columns to bills
-- Run this if your bills table already exists (from an earlier setup).
-- (New setups get these columns from 00_run_all.sql automatically.)

ALTER TABLE bills ADD COLUMN IF NOT EXISTS gst BIGINT NOT NULL DEFAULT 0;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS tds BIGINT NOT NULL DEFAULT 0;

-- Net payable = billed − penalty − gst − tds  (computed in the app, not stored)
