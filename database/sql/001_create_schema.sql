BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS emcasa;
SET search_path TO emcasa, public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('customer', 'admin');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
        CREATE TYPE user_status AS ENUM ('active', 'suspended', 'deleted');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
        CREATE TYPE subscription_status AS ENUM ('pending', 'active', 'expired', 'canceled', 'past_due');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'billing_cycle') THEN
        CREATE TYPE billing_cycle AS ENUM ('annual');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_status') THEN
        CREATE TYPE request_status AS ENUM ('submitted', 'in_analysis', 'in_charge', 'proposal_sent', 'appointment_scheduled', 'closed');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attachment_type') THEN
        CREATE TYPE attachment_type AS ENUM ('image', 'pdf', 'planimetry', 'other');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_channel') THEN
        CREATE TYPE message_channel AS ENUM ('internal', 'email', 'whatsapp', 'push');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'appointment_status') THEN
        CREATE TYPE appointment_status AS ENUM ('proposed', 'confirmed', 'canceled', 'completed', 'no_show');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'appointment_location_type') THEN
        CREATE TYPE appointment_location_type AS ENUM ('online', 'office', 'phone', 'on_site');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_channel') THEN
        CREATE TYPE notification_channel AS ENUM ('in_app', 'email', 'push', 'whatsapp');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_status') THEN
        CREATE TYPE notification_status AS ENUM ('pending', 'sent', 'failed', 'read');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
        CREATE TYPE notification_type AS ENUM ('request_status', 'message', 'appointment', 'subscription', 'system');
    END IF;
END
$$;

CREATE OR REPLACE FUNCTION emcasa.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(150) NOT NULL,
    email CITEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    phone VARCHAR(30),
    role user_role NOT NULL DEFAULT 'customer',
    status user_status NOT NULL DEFAULT 'active',
    privacy_consent BOOLEAN NOT NULL DEFAULT FALSE,
    privacy_consent_at TIMESTAMPTZ,
    marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,
    marketing_consent_at TIMESTAMPTZ,
    terms_accepted_at TIMESTAMPTZ,
    whatsapp_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
    subscription_active BOOLEAN NOT NULL DEFAULT FALSE,
    subscription_expires_at_utc TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    price_eur NUMERIC(10, 2) NOT NULL CHECK (price_eur >= 0),
    billing_cycle billing_cycle NOT NULL DEFAULT 'annual',
    duration_months INTEGER NOT NULL DEFAULT 12 CHECK (duration_months > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
    status subscription_status NOT NULL DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    renewal_at TIMESTAMPTZ,
    canceled_at TIMESTAMPTZ,
    auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
    amount_eur NUMERIC(10, 2) NOT NULL CHECK (amount_eur >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'EUR',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_subscriptions_dates CHECK (ends_at IS NULL OR started_at IS NULL OR ends_at >= started_at)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_end ON subscriptions(ends_at);

CREATE TABLE IF NOT EXISTS subscription_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(40) NOT NULL,
    provider_payment_id VARCHAR(120),
    amount_eur NUMERIC(10, 2) NOT NULL CHECK (amount_eur >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'EUR',
    status payment_status NOT NULL DEFAULT 'pending',
    paid_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,
    raw_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_subscription_provider_payment UNIQUE(provider, provider_payment_id)
);

CREATE INDEX IF NOT EXISTS idx_subscription_payments_subscription ON subscription_payments(subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON subscription_payments(status);

CREATE SEQUENCE IF NOT EXISTS house_request_code_seq START 1;

CREATE TABLE IF NOT EXISTS house_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_code VARCHAR(20) UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_admin_id UUID REFERENCES users(id),
    region VARCHAR(120) NOT NULL,
    province VARCHAR(120) NOT NULL,
    city_or_area VARCHAR(120) NOT NULL,
    budget_min NUMERIC(12, 2) NOT NULL CHECK (budget_min >= 0),
    budget_max NUMERIC(12, 2) NOT NULL CHECK (budget_max >= budget_min),
    property_type VARCHAR(80) NOT NULL,
    property_condition VARCHAR(80) NOT NULL,
    square_meters INTEGER NOT NULL CHECK (square_meters > 0),
    bedrooms SMALLINT NOT NULL CHECK (bedrooms >= 0),
    bathrooms SMALLINT NOT NULL CHECK (bathrooms >= 0),
    has_garden BOOLEAN NOT NULL DEFAULT FALSE,
    has_garage BOOLEAN NOT NULL DEFAULT FALSE,
    has_terrace BOOLEAN NOT NULL DEFAULT FALSE,
    has_pool BOOLEAN NOT NULL DEFAULT FALSE,
    has_cellar BOOLEAN NOT NULL DEFAULT FALSE,
    energy_class VARCHAR(20),
    style VARCHAR(80),
    finishing_level VARCHAR(80),
    desired_timeline VARCHAR(120),
    notes TEXT,
    attachment_url TEXT,
    source_channel VARCHAR(30) NOT NULL DEFAULT 'web',
    status request_status NOT NULL DEFAULT 'submitted',
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_house_requests_user ON house_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_house_requests_admin ON house_requests(assigned_admin_id);
CREATE INDEX IF NOT EXISTS idx_house_requests_status ON house_requests(status);
CREATE INDEX IF NOT EXISTS idx_house_requests_location ON house_requests(region, province, city_or_area);

CREATE OR REPLACE FUNCTION emcasa.generate_house_request_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.request_code IS NULL OR NEW.request_code = '' THEN
        NEW.request_code := 'REQ-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('house_request_code_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_house_requests_code ON house_requests;
CREATE TRIGGER trg_house_requests_code
BEFORE INSERT ON house_requests
FOR EACH ROW
EXECUTE FUNCTION emcasa.generate_house_request_code();

CREATE TABLE IF NOT EXISTS house_request_status_history (
    id BIGSERIAL PRIMARY KEY,
    request_id UUID NOT NULL REFERENCES house_requests(id) ON DELETE CASCADE,
    old_status request_status,
    new_status request_status NOT NULL,
    changed_by_user_id UUID REFERENCES users(id),
    change_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_house_request_status_history_request ON house_request_status_history(request_id, created_at DESC);

CREATE OR REPLACE FUNCTION emcasa.log_house_request_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO house_request_status_history(request_id, old_status, new_status, changed_by_user_id, change_note)
        VALUES (NEW.id, OLD.status, NEW.status, NULL, 'Cambio stato automatico da trigger');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_house_request_status_change ON house_requests;
CREATE TRIGGER trg_house_request_status_change
AFTER UPDATE OF status ON house_requests
FOR EACH ROW
EXECUTE FUNCTION emcasa.log_house_request_status_change();

CREATE TABLE IF NOT EXISTS house_request_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES house_requests(id) ON DELETE CASCADE,
    uploaded_by_user_id UUID REFERENCES users(id),
    attachment_type attachment_type NOT NULL DEFAULT 'other',
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    mime_type VARCHAR(120),
    file_size_bytes BIGINT CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
    is_visible_to_customer BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_house_request_attachments_request ON house_request_attachments(request_id);

CREATE TABLE IF NOT EXISTS communications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES house_requests(id) ON DELETE SET NULL,
    sender_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    recipient_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    channel message_channel NOT NULL DEFAULT 'internal',
    subject VARCHAR(200),
    body TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_communications_request ON communications(request_id);
CREATE INDEX IF NOT EXISTS idx_communications_recipient_unread ON communications(recipient_user_id, is_read);

CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES house_requests(id) ON DELETE CASCADE,
    customer_user_id UUID NOT NULL REFERENCES users(id),
    admin_user_id UUID NOT NULL REFERENCES users(id),
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    location_type appointment_location_type NOT NULL DEFAULT 'online',
    location_details TEXT,
    status appointment_status NOT NULL DEFAULT 'proposed',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_appointments_period CHECK (ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_appointments_request ON appointments(request_id);
CREATE INDEX IF NOT EXISTS idx_appointments_start ON appointments(starts_at);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_id UUID REFERENCES house_requests(id) ON DELETE SET NULL,
    notification_type notification_type NOT NULL DEFAULT 'system',
    title VARCHAR(160) NOT NULL,
    body TEXT NOT NULL,
    delivery_channel notification_channel NOT NULL DEFAULT 'in_app',
    status notification_status NOT NULL DEFAULT 'pending',
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_status ON notifications(user_id, status);

CREATE TABLE IF NOT EXISTS site_content_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) NOT NULL UNIQUE,
    title VARCHAR(160),
    content TEXT NOT NULL,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    updated_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_settings (
    key VARCHAR(120) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    actor_user_id UUID REFERENCES users(id),
    entity_name VARCHAR(80) NOT NULL,
    entity_id UUID,
    action VARCHAR(40) NOT NULL,
    before_data JSONB,
    after_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_name, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_subscription_plans_updated_at ON subscription_plans;
CREATE TRIGGER trg_subscription_plans_updated_at
BEFORE UPDATE ON subscription_plans
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER trg_subscriptions_updated_at
BEFORE UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_subscription_payments_updated_at ON subscription_payments;
CREATE TRIGGER trg_subscription_payments_updated_at
BEFORE UPDATE ON subscription_payments
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_house_requests_updated_at ON house_requests;
CREATE TRIGGER trg_house_requests_updated_at
BEFORE UPDATE ON house_requests
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_appointments_updated_at ON appointments;
CREATE TRIGGER trg_appointments_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_notifications_updated_at ON notifications;
CREATE TRIGGER trg_notifications_updated_at
BEFORE UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_site_content_blocks_updated_at ON site_content_blocks;
CREATE TRIGGER trg_site_content_blocks_updated_at
BEFORE UPDATE ON site_content_blocks
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

DROP TRIGGER IF EXISTS trg_app_settings_updated_at ON app_settings;
CREATE TRIGGER trg_app_settings_updated_at
BEFORE UPDATE ON app_settings
FOR EACH ROW
EXECUTE FUNCTION emcasa.set_updated_at();

COMMIT;
