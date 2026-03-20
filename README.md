# E&M Casa Personalizzata - Fase 1

Setup iniziale del progetto con stack:
- Backend: ASP.NET Core Web API (.NET 8)
- Frontend: React + Vite (Node.js)
- Database: PostgreSQL

## Struttura

- `src/backend/EmCasa.Api`: API backend
- `src/frontend`: Web app frontend (sito vetrina + area cliente + area admin)
- `docker-compose.yml`: servizio PostgreSQL locale
- `database/sql`: script SQL versionati per schema completo DB

## Requisiti

- .NET SDK 8+ (compatibile con SDK 9)
- Node.js 20+
- Docker Desktop (opzionale ma consigliato per PostgreSQL)

## Avvio rapido

1. Avvia PostgreSQL:
   - `docker compose up -d`

2. Avvia backend:
   - `dotnet run --project src/backend/EmCasa.Api`
   - API base URL: `http://localhost:5240`
   - Swagger: `http://localhost:5240/swagger`

3. Avvia frontend:
   - `cd src/frontend`
   - `copy .env.example .env`
   - `npm install`
   - `npm run dev`
   - Web app URL: `http://localhost:5173`

## Script database (consigliato)

Per creare il database completo secondo specifica progetto (utenti, abbonamenti, richieste, allegati, comunicazioni, appuntamenti, notifiche, contenuti sito, audit):

1. Avvia PostgreSQL:
  - `docker compose up -d`

2. Esegui gli script nell'ordine:
  - `docker cp .\database\sql\001_create_schema.sql emcasa-postgres:/tmp/001_create_schema.sql`
  - `docker exec emcasa-postgres psql -v ON_ERROR_STOP=1 -U postgres -d emcasa_db -f /tmp/001_create_schema.sql`
  - `docker cp .\database\sql\002_seed_initial_data.sql emcasa-postgres:/tmp/002_seed_initial_data.sql`
  - `docker exec emcasa-postgres psql -v ON_ERROR_STOP=1 -U postgres -d emcasa_db -f /tmp/002_seed_initial_data.sql`
  - `docker cp .\database\sql\003_views_reporting.sql emcasa-postgres:/tmp/003_views_reporting.sql`
  - `docker exec emcasa-postgres psql -v ON_ERROR_STOP=1 -U postgres -d emcasa_db -f /tmp/003_views_reporting.sql`

Dettagli in `database/sql/README.md`.

## Credenziali admin seed (dev)

Configurate in `src/backend/EmCasa.Api/appsettings.Development.json`:
- Email: `admin@emcasa.local`
- Password: `Admin123!`

## API principali Fase 1

- Pubblico:
  - `GET /api/public/site-content`

- Auth:
  - `POST /api/auth/register`
  - `POST /api/auth/login`
  - `GET /api/me`

- Cliente:
  - `POST /api/subscription/activate`
  - `POST /api/house-requests`
  - `GET /api/house-requests/me`

- Admin:
  - `GET /api/admin/users`
  - `GET /api/admin/house-requests`
  - `PATCH /api/admin/house-requests/{id}/status`

## Note

- Il backend usa schema SQL-first: prima eseguire gli script in `database/sql`.
- Gli script in `database/sql` definiscono uno schema dati completo coerente con la documentazione funzionale.
- Prima del deploy in produzione, sostituire chiavi JWT e password seed con valori sicuri.

## Connessione database AWS (RDS/PostgreSQL)

Il backend ora supporta sia `ConnectionStrings__DefaultConnection` sia `DATABASE_URL`.

Esempio PowerShell (sessione corrente):

- `ConnectionStrings__DefaultConnection`:
  - `$env:ConnectionStrings__DefaultConnection = "Host=<AWS_HOST>;Port=5432;Database=<DB_NAME>;Username=<DB_USER>;Password=<DB_PASSWORD>;SSL Mode=Require"`

- `DATABASE_URL`:
  - `$env:DATABASE_URL = "postgres://<DB_USER>:<DB_PASSWORD>@<AWS_HOST>:5432/<DB_NAME>?sslmode=require"`

Poi avvia l'API:

- `dotnet run --project src/backend/EmCasa.Api`
