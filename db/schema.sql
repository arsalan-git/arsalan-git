-- Super Complete Real Estate Management Software
-- PostgreSQL-oriented draft schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========================================================
-- Shared reference enums (using TEXT + CHECK keeps migration flexibility)
-- =========================================================

-- =========================================================
-- MODULE 0 – COMPANY & PLATFORM OWNER
-- =========================================================

CREATE TABLE IF NOT EXISTS company_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name TEXT NOT NULL,
  trade_name TEXT,
  email TEXT,
  phone TEXT,
  address_line_1 TEXT,
  address_line_2 TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  postal_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS company_active_member_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES company_register(id),
  contact_id UUID NOT NULL,
  position_title TEXT NOT NULL,
  role_code TEXT NOT NULL,
  has_login_access BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  valid_from DATE,
  valid_to DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_company_member_validity CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);

-- =========================================================
-- MODULE 1 – CRM (MASTER DATA)
-- =========================================================

CREATE TABLE IF NOT EXISTS contact_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_type TEXT NOT NULL CHECK (contact_type IN ('INDIVIDUAL', 'ORGANIZATION')),
  display_name TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  organization_name TEXT,
  email TEXT,
  phone TEXT,
  alt_phone TEXT,
  gst_number TEXT,
  pan_number TEXT,
  aadhaar_number TEXT,
  address_line_1 TEXT,
  address_line_2 TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  postal_code TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE company_active_member_list
  ADD CONSTRAINT fk_company_member_contact
  FOREIGN KEY (contact_id) REFERENCES contact_register(id);

CREATE TABLE IF NOT EXISTS vendor_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID NOT NULL UNIQUE REFERENCES contact_register(id),
  service_category TEXT,
  gst_number TEXT,
  bank_name TEXT,
  bank_account_no TEXT,
  ifsc_code TEXT,
  upi_id TEXT,
  payment_terms TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- MODULE 2 – REAL ESTATE PROPERTY & SOCIETY MANAGEMENT
-- =========================================================

CREATE TABLE IF NOT EXISTS society_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_name TEXT NOT NULL,
  society_type TEXT,
  registration_no TEXT,
  registration_date DATE,
  building_name TEXT,
  land_survey_no TEXT,
  address_line_1 TEXT,
  address_line_2 TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  postal_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS society_member_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  contact_id UUID NOT NULL REFERENCES contact_register(id),
  role_code TEXT NOT NULL CHECK (role_code IN ('CHAIRMAN', 'SECRETARY', 'TREASURER', 'MEMBER', 'ASSOCIATE_MEMBER')),
  valid_from DATE,
  valid_to DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_society_member_validity CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);

CREATE TABLE IF NOT EXISTS property_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID REFERENCES society_register(id),
  property_code TEXT UNIQUE,
  property_name TEXT,
  property_type TEXT,
  unit_no TEXT,
  wing_block TEXT,
  floor_no TEXT,
  carpet_area_sqft NUMERIC(12,2),
  builtup_area_sqft NUMERIC(12,2),
  address_line_1 TEXT,
  address_line_2 TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  postal_code TEXT,
  is_rentable BOOLEAN NOT NULL DEFAULT false,
  is_currently_rented BOOLEAN NOT NULL DEFAULT false,
  is_self_occupied BOOLEAN NOT NULL DEFAULT false,
  is_vacate BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_owner_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES property_list(id),
  contact_id UUID NOT NULL REFERENCES contact_register(id),
  ownership_percentage NUMERIC(5,2) NOT NULL CHECK (ownership_percentage >= 0 AND ownership_percentage <= 100),
  valid_from DATE,
  valid_to DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_property_owner_validity CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);

CREATE TABLE IF NOT EXISTS amc_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID REFERENCES society_register(id),
  property_id UUID REFERENCES property_list(id),
  vendor_id UUID NOT NULL REFERENCES vendor_register(id),
  amc_name TEXT NOT NULL,
  contract_no TEXT,
  scope_of_work TEXT,
  start_date DATE,
  end_date DATE,
  amount NUMERIC(14,2),
  status TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_amc_validity CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS amc_tenure (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_id UUID NOT NULL REFERENCES amc_register(id),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  renewal_due_date DATE,
  is_renewed BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_amc_tenure_validity CHECK (end_date >= start_date)
);

-- =========================================================
-- MODULE 3 – MAINTENANCE & COMPLAINT MANAGEMENT
-- =========================================================

CREATE TABLE IF NOT EXISTS complaint_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_no TEXT UNIQUE,
  raised_by_contact_id UUID NOT NULL REFERENCES contact_register(id),
  society_id UUID REFERENCES society_register(id),
  property_id UUID REFERENCES property_list(id),
  category TEXT NOT NULL,
  priority TEXT NOT NULL CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  status TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT,
  raised_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS complaint_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id UUID NOT NULL REFERENCES complaint_register(id),
  action_type TEXT NOT NULL,
  action_note TEXT,
  performed_by_contact_id UUID REFERENCES contact_register(id),
  vendor_id UUID REFERENCES vendor_register(id),
  status_after_action TEXT,
  action_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS complaint_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id UUID REFERENCES complaint_register(id),
  activity_id UUID REFERENCES complaint_activities(id),
  document_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  mime_type TEXT,
  uploaded_by_contact_id UUID REFERENCES contact_register(id),
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- MODULE 4 – RENTAL ESTATE PROPERTY LEASE MANAGEMENT
-- =========================================================

CREATE TABLE IF NOT EXISTS rented_property_rent_tenures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES property_list(id),
  lease_start_date DATE NOT NULL,
  lease_end_date DATE NOT NULL,
  monthly_rent NUMERIC(14,2) NOT NULL,
  security_deposit NUMERIC(14,2),
  escalation_type TEXT,
  escalation_value NUMERIC(10,2),
  escalation_frequency_months INTEGER,
  lock_in_months INTEGER,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_rent_tenure_validity CHECK (lease_end_date >= lease_start_date)
);

CREATE TABLE IF NOT EXISTS tenant_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID NOT NULL REFERENCES contact_register(id),
  property_id UUID NOT NULL REFERENCES property_list(id),
  rent_tenure_id UUID REFERENCES rented_property_rent_tenures(id),
  society_associate_member_id UUID REFERENCES society_member_list(id),
  tenant_type TEXT,
  move_in_date DATE,
  move_out_date DATE,
  is_current_tenant BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_tenant_dates CHECK (move_out_date IS NULL OR move_in_date IS NULL OR move_out_date >= move_in_date)
);

CREATE TABLE IF NOT EXISTS rented_property_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_tenure_id UUID NOT NULL REFERENCES rented_property_rent_tenures(id),
  tenant_id UUID REFERENCES tenant_list(id),
  document_type TEXT NOT NULL,
  document_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  issue_date DATE,
  expiry_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS check_list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_code TEXT UNIQUE,
  item_name TEXT NOT NULL,
  item_description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_vacating_reporting_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_tenure_id UUID NOT NULL REFERENCES rented_property_rent_tenures(id),
  tenant_id UUID REFERENCES tenant_list(id),
  check_list_item_id UUID NOT NULL REFERENCES check_list_items(id),
  status TEXT NOT NULL,
  remarks TEXT,
  checked_by_contact_id UUID REFERENCES contact_register(id),
  checked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_possession_reporting_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_tenure_id UUID NOT NULL REFERENCES rented_property_rent_tenures(id),
  tenant_id UUID REFERENCES tenant_list(id),
  check_list_item_id UUID NOT NULL REFERENCES check_list_items(id),
  status TEXT NOT NULL,
  remarks TEXT,
  checked_by_contact_id UUID REFERENCES contact_register(id),
  checked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- MODULE 5 – RENTAL FINANCIALS
-- =========================================================

CREATE TABLE IF NOT EXISTS rent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_tenure_id UUID NOT NULL REFERENCES rented_property_rent_tenures(id),
  tenant_id UUID REFERENCES tenant_list(id),
  due_period_start DATE NOT NULL,
  due_period_end DATE NOT NULL,
  due_date DATE NOT NULL,
  amount_due NUMERIC(14,2) NOT NULL,
  amount_received NUMERIC(14,2) NOT NULL DEFAULT 0,
  balance_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_rent_record_period CHECK (due_period_end >= due_period_start)
);

CREATE TABLE IF NOT EXISTS rent_received (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_record_id UUID NOT NULL REFERENCES rent_records(id),
  tenant_id UUID REFERENCES tenant_list(id),
  amount_received NUMERIC(14,2) NOT NULL,
  received_date DATE NOT NULL,
  payment_mode TEXT,
  reference_no TEXT,
  remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS other_charges_received (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_tenure_id UUID REFERENCES rented_property_rent_tenures(id),
  tenant_id UUID REFERENCES tenant_list(id),
  charge_type TEXT NOT NULL,
  amount_received NUMERIC(14,2) NOT NULL,
  received_date DATE NOT NULL,
  payment_mode TEXT,
  reference_no TEXT,
  remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bonds_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_tenure_id UUID NOT NULL REFERENCES rented_property_rent_tenures(id),
  tenant_id UUID REFERENCES tenant_list(id),
  deposit_amount NUMERIC(14,2) NOT NULL,
  adjustment_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  refund_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  transaction_date DATE,
  remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- MODULE 6 – SOCIETY FINANCIALS
-- =========================================================

CREATE TABLE IF NOT EXISTS society_account_heads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  head_code TEXT NOT NULL,
  head_name TEXT NOT NULL,
  head_type TEXT NOT NULL CHECK (head_type IN ('ASSET', 'LIABILITY', 'INCOME', 'EXPENSE', 'EQUITY')),
  parent_head_id UUID REFERENCES society_account_heads(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (society_id, head_code)
);

CREATE TABLE IF NOT EXISTS invoice_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  invoice_no TEXT NOT NULL,
  invoice_date DATE NOT NULL,
  due_date DATE,
  billed_to_contact_id UUID REFERENCES contact_register(id),
  billed_to_property_id UUID REFERENCES property_list(id),
  total_amount NUMERIC(14,2) NOT NULL,
  tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  net_amount NUMERIC(14,2) NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (society_id, invoice_no)
);

CREATE TABLE IF NOT EXISTS invoice_items_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoice_register(id),
  account_head_id UUID REFERENCES society_account_heads(id),
  description TEXT NOT NULL,
  quantity NUMERIC(12,2) NOT NULL DEFAULT 1,
  unit_rate NUMERIC(14,2) NOT NULL DEFAULT 0,
  tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  line_total NUMERIC(14,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchase_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  purchase_no TEXT NOT NULL,
  purchase_date DATE NOT NULL,
  vendor_id UUID REFERENCES vendor_register(id),
  total_amount NUMERIC(14,2) NOT NULL,
  tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  net_amount NUMERIC(14,2) NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (society_id, purchase_no)
);

CREATE TABLE IF NOT EXISTS purchase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID NOT NULL REFERENCES purchase_register(id),
  account_head_id UUID REFERENCES society_account_heads(id),
  description TEXT NOT NULL,
  quantity NUMERIC(12,2) NOT NULL DEFAULT 1,
  unit_rate NUMERIC(14,2) NOT NULL DEFAULT 0,
  tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  line_total NUMERIC(14,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS credit_note (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  credit_note_no TEXT NOT NULL,
  credit_note_date DATE NOT NULL,
  reference_invoice_id UUID REFERENCES invoice_register(id),
  amount NUMERIC(14,2) NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (society_id, credit_note_no)
);

CREATE TABLE IF NOT EXISTS debit_note (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  debit_note_no TEXT NOT NULL,
  debit_note_date DATE NOT NULL,
  reference_purchase_id UUID REFERENCES purchase_register(id),
  amount NUMERIC(14,2) NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (society_id, debit_note_no)
);

CREATE TABLE IF NOT EXISTS financial_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  transaction_date DATE NOT NULL,
  account_head_id UUID NOT NULL REFERENCES society_account_heads(id),
  dr_cr TEXT NOT NULL CHECK (dr_cr IN ('DR', 'CR')),
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  source_type TEXT,
  source_id UUID,
  narration TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_contact_id UUID REFERENCES contact_register(id)
);

CREATE TABLE IF NOT EXISTS financial_snapshot (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  account_head_id UUID REFERENCES society_account_heads(id),
  opening_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_debits NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_credits NUMERIC(14,2) NOT NULL DEFAULT 0,
  closing_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_locked BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT chk_fin_snapshot_period CHECK (period_end >= period_start)
);

CREATE TABLE IF NOT EXISTS list_of_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  asset_code TEXT,
  asset_name TEXT NOT NULL,
  category TEXT,
  purchase_date DATE,
  purchase_value NUMERIC(14,2),
  useful_life_months INTEGER,
  residual_value NUMERIC(14,2),
  status TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (society_id, asset_code)
);

CREATE TABLE IF NOT EXISTS society_valuation_snapshot (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  valuation_date DATE NOT NULL,
  total_assets_value NUMERIC(14,2) NOT NULL,
  total_liabilities NUMERIC(14,2) NOT NULL,
  net_society_value NUMERIC(14,2) NOT NULL,
  remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_contact_id UUID REFERENCES contact_register(id)
);

CREATE TABLE IF NOT EXISTS society_share_details (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  valuation_snapshot_id UUID NOT NULL REFERENCES society_valuation_snapshot(id),
  property_owner_id UUID NOT NULL REFERENCES property_owner_list(id),
  ownership_percentage NUMERIC(5,2) NOT NULL,
  share_value NUMERIC(14,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_trail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_name TEXT NOT NULL,
  entity_name TEXT NOT NULL,
  entity_id UUID,
  action_type TEXT NOT NULL,
  action_note TEXT,
  actor_contact_id UUID REFERENCES contact_register(id),
  actor_email TEXT,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS accounts_documents_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID REFERENCES society_register(id),
  source_type TEXT NOT NULL,
  source_id UUID,
  document_type TEXT,
  document_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  uploaded_by_contact_id UUID REFERENCES contact_register(id),
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- MODULE 7 – LEGAL & COMPLIANCE
-- =========================================================

CREATE TABLE IF NOT EXISTS society_documents_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES society_register(id),
  document_type TEXT NOT NULL,
  document_name TEXT NOT NULL,
  registration_no TEXT,
  issue_date DATE,
  expiry_date DATE,
  is_mortgaged BOOLEAN NOT NULL DEFAULT false,
  file_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_document_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES property_list(id),
  document_type TEXT NOT NULL,
  document_name TEXT NOT NULL,
  deed_no TEXT,
  issue_date DATE,
  expiry_date DATE,
  encumbrance_details TEXT,
  file_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- MODULE 8 – BROADCASTING & COMMUNICATION
-- =========================================================

CREATE TABLE IF NOT EXISTS broadcast_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_title TEXT NOT NULL,
  message_content TEXT NOT NULL,
  purpose TEXT,
  scheduled_at TIMESTAMPTZ,
  created_by_contact_id UUID REFERENCES contact_register(id),
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS broadcast_recipients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id UUID NOT NULL REFERENCES broadcast_master(id),
  recipient_contact_id UUID REFERENCES contact_register(id),
  recipient_society_id UUID REFERENCES society_register(id),
  recipient_property_id UUID REFERENCES property_list(id),
  recipient_role_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS broadcast_channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id UUID NOT NULL REFERENCES broadcast_master(id),
  channel_type TEXT NOT NULL CHECK (channel_type IN ('IN_APP', 'EMAIL', 'SMS', 'WHATSAPP')),
  channel_config JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS broadcast_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id UUID NOT NULL REFERENCES broadcast_master(id),
  recipient_contact_id UUID REFERENCES contact_register(id),
  channel_type TEXT NOT NULL,
  delivery_status TEXT NOT NULL,
  read_status TEXT,
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  response_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- Useful indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_property_society ON property_list (society_id);
CREATE INDEX IF NOT EXISTS idx_owner_property ON property_owner_list (property_id);
CREATE INDEX IF NOT EXISTS idx_complaint_status ON complaint_register (status);
CREATE INDEX IF NOT EXISTS idx_tenure_property ON rented_property_rent_tenures (property_id);
CREATE INDEX IF NOT EXISTS idx_rent_record_tenure ON rent_records (rent_tenure_id);
CREATE INDEX IF NOT EXISTS idx_ledger_society_date ON financial_transactions (society_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_snapshot_society_period ON financial_snapshot (society_id, period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_broadcast_status ON broadcast_master (status);
