# Script database PostgreSQL (Fase 1)

Ordine di esecuzione:

1. `001_create_schema.sql` - Crea schema, tipi enum, tabelle, indici e trigger.
2. `002_seed_initial_data.sql` - Inserisce piano abbonamento, contenuti sito e configurazioni base.
3. `003_views_reporting.sql` - Crea viste per pannello admin/export.

## Esecuzione rapida (Docker)

Da root progetto:

```powershell
docker compose up -d
docker cp .\database\sql\001_create_schema.sql emcasa-postgres:/tmp/001_create_schema.sql
docker exec emcasa-postgres psql -v ON_ERROR_STOP=1 -U postgres -d emcasa_db -f /tmp/001_create_schema.sql
docker cp .\database\sql\002_seed_initial_data.sql emcasa-postgres:/tmp/002_seed_initial_data.sql
docker exec emcasa-postgres psql -v ON_ERROR_STOP=1 -U postgres -d emcasa_db -f /tmp/002_seed_initial_data.sql
docker cp .\database\sql\003_views_reporting.sql emcasa-postgres:/tmp/003_views_reporting.sql
docker exec emcasa-postgres psql -v ON_ERROR_STOP=1 -U postgres -d emcasa_db -f /tmp/003_views_reporting.sql
```

## Nota importante

Questi script implementano una base dati completa coerente con la documentazione funzionale (utenti, abbonamenti, richieste casa, allegati, comunicazioni, appuntamenti, notifiche, contenuti sito, audit).

Il backend API è allineato a questo schema (`emcasa` + naming snake_case), quindi gli script vanno eseguiti prima dell'avvio applicazione.
