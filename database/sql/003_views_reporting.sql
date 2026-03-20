BEGIN;

SET search_path TO emcasa, public;

CREATE OR REPLACE VIEW vw_admin_house_requests AS
SELECT
    hr.id,
    hr.request_code,
    hr.status,
    hr.region,
    hr.province,
    hr.city_or_area,
    hr.budget_min,
    hr.budget_max,
    hr.property_type,
    hr.property_condition,
    hr.square_meters,
    hr.bedrooms,
    hr.bathrooms,
    hr.created_at,
    hr.updated_at,
    hr.submitted_at,
    hr.closed_at,
    cu.id AS customer_id,
    cu.full_name AS customer_name,
    cu.email AS customer_email,
    au.id AS admin_id,
    au.full_name AS admin_name,
    au.email AS admin_email
FROM house_requests hr
JOIN users cu ON cu.id = hr.user_id
LEFT JOIN users au ON au.id = hr.assigned_admin_id;

CREATE OR REPLACE VIEW vw_active_subscriptions AS
SELECT
    s.id AS subscription_id,
    u.id AS user_id,
    u.full_name,
    u.email,
    sp.code AS plan_code,
    sp.name AS plan_name,
    s.status,
    s.started_at,
    s.ends_at,
    s.renewal_at,
    s.amount_eur,
    s.currency
FROM subscriptions s
JOIN users u ON u.id = s.user_id
JOIN subscription_plans sp ON sp.id = s.plan_id
WHERE s.status = 'active';

CREATE OR REPLACE VIEW vw_export_customers AS
SELECT
    u.id,
    u.full_name,
    u.email,
    u.phone,
    u.status,
    u.privacy_consent,
    u.marketing_consent,
    u.whatsapp_opt_in,
    u.created_at,
    COUNT(DISTINCT hr.id) AS total_house_requests,
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'active') AS active_subscriptions
FROM users u
LEFT JOIN house_requests hr ON hr.user_id = u.id
LEFT JOIN subscriptions s ON s.user_id = u.id
GROUP BY
    u.id,
    u.full_name,
    u.email,
    u.phone,
    u.status,
    u.privacy_consent,
    u.marketing_consent,
    u.whatsapp_opt_in,
    u.created_at;

COMMIT;
