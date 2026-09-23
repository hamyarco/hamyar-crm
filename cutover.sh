#!/usr/bin/env bash
# crm.hamyar.co — final cutover from srv004 (185.112.151.120) to this server.
#
# Run this ONLY at the agreed moment: it throws away the copy that is live in
# /opt/hamyar-crm and replaces it with a fresh one from the old server, so any
# change made on THIS server since the trial import is lost (that is the point —
# the old server is the source of truth until the Cloudflare record moves).
#
#   ./cutover.sh            # dump + restore + file sync, old site stays writable
#   ./cutover.sh --freeze   # stop the old site's PHP pool first (no writes can be
#                           # lost, but the old CRM is down for the copy, ~5-10 min)
#
# After it finishes: move the Cloudflare A record for `crm` to 212.38.94.166,
# grey cloud, run `certbot --nginx -d crm.hamyar.co`, then turn the orange cloud
# back on with SSL mode Full (strict).
set -euo pipefail

SRC=185.112.151.120
SRC_DIR=/home/hamyar-crm/htdocs/crm.hamyar.co
HERE=/opt/hamyar-crm
STAMP=$(date +%Y%m%d-%H%M)
FREEZE=${1:-}

# The old server still uses password auth. Export SSHPASS before running:
#   read -rs SSHPASS; export SSHPASS; ./cutover.sh
# (nothing is written to disk). If a key is installed later, unset SSHPASS and
# both helpers fall through to plain ssh/rsync.
if [ -n "${SSHPASS:-}" ]; then SSH_WRAP=(sshpass -e); else SSH_WRAP=(); fi
ssh_src()   { "${SSH_WRAP[@]}" ssh -o StrictHostKeyChecking=no "root@$SRC" "$@"; }
rsync_src() { "${SSH_WRAP[@]}" rsync -e 'ssh -o StrictHostKeyChecking=no' "$@"; }

echo "==> 1/7 stop the old vtiger cron (no double workflow runs)"
ssh_src 'mv -f /etc/cron.d/hamyar-crm /root/hamyar-crm.cron.disabled 2>/dev/null || true'

if [ "$FREEZE" = "--freeze" ]; then
  echo "==> 1b   freeze the old site (php8.3-fpm stopped)"
  ssh_src 'systemctl stop php8.3-fpm'
fi

echo "==> 2/7 safety copy of what is live here"
docker exec hamyar-crm-db-1 sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction vtiger' \
  | gzip -1 > "$HERE/backups/pre-cutover-$STAMP.sql.gz"

echo "==> 3/7 fresh dump on the old server"
ssh_src "mysqldump --defaults-file=/root/.crmdb.cnf --single-transaction --quick --routines --triggers --events \
         --default-character-set=utf8mb4 --hex-blob hamyar-crm | gzip -1 > /root/crm-migrate/crm-db.sql.gz"

echo "==> 4/7 pull the dump and the files that changed"
rsync_src -a --info=progress2 \
      "root@$SRC:/root/crm-migrate/crm-db.sql.gz" "$HERE/migrate/"
rsync_src -a --delete --info=progress2 \
      --exclude 'cache/templates_c/' --exclude 'cache/vtlib/' --exclude 'logs/' \
      --exclude 'config.inc.php' \
      "root@$SRC:$SRC_DIR/" "$HERE/html/"
chown -R 33:33 "$HERE/html"

echo "==> 5/7 restore into the vtiger database"
docker exec hamyar-crm-db-1 sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "DROP DATABASE vtiger; CREATE DATABASE vtiger CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'
gunzip -c "$HERE/migrate/crm-db.sql.gz" \
  | docker exec -i hamyar-crm-db-1 sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" --default-character-set=utf8mb4 vtiger'

echo "==> 6/7 clear caches and restart the container"
rm -rf "$HERE"/html/cache/templates_c/* "$HERE"/html/cache/vtlib/* 2>/dev/null || true
docker compose -f "$HERE/docker-compose.yml" --project-directory "$HERE" restart crm
sleep 5
curl -fsS -o /dev/null -H 'Host: crm.hamyar.co' http://127.0.0.1/index.php && echo "    login page renders OK"

echo "==> 7/7 enable the vtiger cron on THIS server"
cat > /etc/cron.d/hamyar-crm <<'CRON'
# vtiger scheduled workflows / mail scanner — mirrors what srv004 ran every 10 min
*/10 * * * * root curl -fsS -m 300 -H 'Host: crm.hamyar.co' http://127.0.0.1/vtigercron.php > /dev/null 2>&1
CRON
chmod 644 /etc/cron.d/hamyar-crm

echo
echo "Done. Now, in Cloudflare:"
echo "  crm  A  212.38.94.166   (DNS only / grey cloud)"
echo "then: certbot --nginx -d crm.hamyar.co"
echo "then: turn the orange cloud back on, SSL mode Full (strict)."
[ "$FREEZE" = "--freeze" ] && echo "NOTE: php8.3-fpm on the old server is still stopped - leave it that way."
