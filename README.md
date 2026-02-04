# Registratie

Phoenix + CouchDB registratie-app.

## Lokaal draaien
- `mix setup`
- `mix phx.server` en open http://localhost:4000

## Deploy naar Fly.io (app)
- Installeer `flyctl` en login.
- `flyctl launch --name registratie --no-deploy --copy-config` (pas `app` en `primary_region` in `fly.toml` aan als nodig).
- Secrets zetten (voorbeeld):
  ```
  flyctl secrets set SECRET_KEY_BASE=$(mix phx.gen.secret) \
    COUCHDB_URL="http://registratie-couch.internal:5984" \
    COUCHDB_USERNAME="admin" \
    COUCHDB_PASSWORD="supersecret" \
    PHX_HOST="registratie.fly.dev"
  ```
  `DATABASE_URL` wordt automatisch gezet als je een Fly Postgres installeert (zie hieronder), anders zelf zetten.
- Deploy: `flyctl deploy`
- Migrate (Postgres): `flyctl ssh console -C "/app/bin/registratie eval 'Registratie.Release.migrate'"` na elke schema-wijziging.

## Postgres op Fly (kleinste optie)
- `flyctl postgres create --name registratie-db --region ams --initial-cluster-size 1 --vm-size shared-cpu-1x --volume-size 1`
- Koppel aan app: `flyctl postgres attach --app registratie --postgres-app registratie-db`

## CouchDB op Fly (goedkoopste setup)
- Nieuwe app: `flyctl launch --name registratie-couch --image couchdb:3 --no-deploy --region ams`
- Volume: `flyctl volumes create couchdata --size 1 --region ams --app registratie-couch`
- Secrets voor Couch: `flyctl secrets set -a registratie-couch COUCHDB_USER=admin COUCHDB_PASSWORD=supersecret`
- Deploy Couch: `flyctl deploy -a registratie-couch`
- Verbind vanuit de Phoenix-app via interne hostname: `COUCHDB_URL=http://registratie-couch.internal:5984` + dezelfde gebruikersnaam/wachtwoord in `COUCHDB_USERNAME` en `COUCHDB_PASSWORD`.

## Kosten laag houden op Fly
- `fly scale vm shared-cpu-1x --memory 256` voor zowel app als CouchDB.
- `fly secrets unset` voor oude secrets om koude starts te versnellen.
- `fly toml` heeft `auto_stop_machines=true` en `min_machines_running=0` zodat de app in slaap kan; houd rekening met koude starts.
