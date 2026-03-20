BEGIN;

SET search_path TO emcasa, public;

INSERT INTO subscription_plans (code, name, description, price_eur, billing_cycle, duration_months, is_active)
VALUES
    ('ANNUAL_1499', 'Piano Annuale E&M', 'Abbonamento annuale per accesso area riservata e gestione pratica casa personalizzata', 14.99, 'annual', 12, TRUE)
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price_eur = EXCLUDED.price_eur,
    billing_cycle = EXCLUDED.billing_cycle,
    duration_months = EXCLUDED.duration_months,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

INSERT INTO site_content_blocks (slug, title, content, is_published, sort_order)
VALUES
    ('home', 'Home', 'Trova o realizza la tua casa personalizzata in Italia con il supporto di E&M Srl.', TRUE, 10),
    ('come-funziona', 'Come funziona', 'Registrati, attiva l''abbonamento annuale, compila la richiesta e monitora lo stato della pratica.', TRUE, 20),
    ('abbonamento', 'Abbonamento', 'Abbonamento annuale: 14,99 EUR.', TRUE, 30),
    ('chi-siamo', 'Chi siamo', 'E&M Srl offre assistenza completa per ricerca, valutazione e sviluppo della casa personalizzata.', TRUE, 40),
    ('contatti', 'Contatti', 'Telefono: 3282054849 - Email: emsrlimpresa@gmail.com - Sede: Lavezzola, Via Adige 1, Comune di Conselice', TRUE, 50)
ON CONFLICT (slug) DO UPDATE
SET
    title = EXCLUDED.title,
    content = EXCLUDED.content,
    is_published = EXCLUDED.is_published,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

INSERT INTO app_settings (key, value, description)
VALUES
    ('company_profile',
     '{"name":"E&M Srl","brand":"E&M Casa Personalizzata","phone":"3282054849","email":"emsrlimpresa@gmail.com","address":"Lavezzola, Via Adige 1, Comune di Conselice"}'::jsonb,
     'Anagrafica aziendale mostrata su sito e pannello admin'),
    ('subscription_defaults',
     '{"annual_price_eur":14.99,"currency":"EUR","duration_months":12}'::jsonb,
     'Valori di default per sottoscrizione annuale'),
    ('contact_channels',
     '{"whatsapp_enabled":true,"whatsapp_number":"+393282054849","email_enabled":true,"push_enabled":true}'::jsonb,
     'Canali contatto/notifica lato cliente')
ON CONFLICT (key) DO UPDATE
SET
    value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = NOW();

COMMIT;
