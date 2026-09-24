#!/usr/bin/env bash
# Wire the Pulse dashboard to the CRM, read-only. Run once.
#
#   /opt/hamyar-crm/connect-pulse.sh
#
# It: creates a SELECT-only `pulse_ro` user on the CRM database with a fresh random
# password, publishes the CRM database on 127.0.0.1:3307 (loopback only — the db
# container restarts, ~10 seconds during which the CRM cannot reach its database),
# writes the password into Pulse's .env, and restarts the Pulse worker.
#
# Nothing here writes to the CRM: pulse_ro has SELECT and nothing else.
set -euo pipefail

CRM=/opt/hamyar-crm
PULSE=/var/www/hamyar-pulse

[ -f "$PULSE/.env" ] || { echo "no $PULSE/.env — is Pulse installed?" >&2; exit 1; }

echo "==> 1/4 read-only user on the CRM database"
PW=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 28)
printf '%s\n' \
  "CREATE USER IF NOT EXISTS 'pulse_ro'@'%' IDENTIFIED BY '$PW';" \
  "ALTER USER 'pulse_ro'@'%' IDENTIFIED BY '$PW';" \
  "GRANT SELECT ON vtiger.* TO 'pulse_ro'@'%';" \
  "FLUSH PRIVILEGES;" \
  | docker exec -i hamyar-crm-db-1 sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'

echo "==> 2/4 publish the CRM database on 127.0.0.1:3307"
docker compose -f "$CRM/docker-compose.yml" --project-directory "$CRM" up -d db
for i in $(seq 1 30); do
  docker exec hamyar-crm-db-1 healthcheck.sh --connect >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS -o /dev/null -H 'Host: crm.hamyar.co' http://127.0.0.1/index.php && echo "    CRM still serving"

echo "==> 3/4 hand the credential to Pulse"
sed -i '/^CRM_DB_/d' "$PULSE/.env"
cat >> "$PULSE/.env" <<ENV
CRM_DB_HOST=127.0.0.1
CRM_DB_PORT=3307
CRM_DB_NAME=vtiger
CRM_DB_USER=pulse_ro
CRM_DB_PASSWORD=$PW
ENV
chmod 600 "$PULSE/.env"

echo "==> 4/4 rebuild and restart the Pulse worker"
docker compose -f "$PULSE/docker-compose.yml" --project-directory "$PULSE" up -d --build worker web

echo
echo "Done. Watch the first sync with:"
echo "  docker compose -f $PULSE/docker-compose.yml --project-directory $PULSE logs -f worker"
