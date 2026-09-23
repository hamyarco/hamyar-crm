#!/usr/bin/env bash
# Full backup of crm.hamyar.co: database + the vtiger tree + the PCG loader/licence
# + this deployment's own files. Keeps the last 7.
#   /opt/hamyar-crm/backup.sh
set -euo pipefail

HERE=/opt/hamyar-crm
DEST=/root/backups/crm
STAMP=$(date +%Y-%m-%d-%H%M)
OUT="$DEST/$STAMP"
mkdir -p "$OUT"

# database
docker exec hamyar-crm-db-1 sh -c \
  'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --quick --routines \
   --triggers --events --default-character-set=utf8mb4 --hex-blob vtiger' \
  | gzip -1 > "$OUT/database.sql.gz"

# the vtiger tree (includes the PersianCRM-encrypted files — they cannot be re-downloaded)
tar -czf "$OUT/html.tar.gz" -C "$HERE" html

# the PCG loader + the domain-locked licence, and this deployment's config
tar -czf "$OUT/deploy.tar.gz" -C "$HERE" pcg .env docker-compose.yml Dockerfile php.ini \
    apache.conf cutover.sh backup.sh cron.d-hamyar-crm .gitignore README.md

( cd "$OUT" && sha256sum ./* > SHA256SUMS )
du -sh "$OUT" > "$OUT/SIZE"

# keep the last 7
ls -1dt "$DEST"/*/ 2>/dev/null | tail -n +8 | xargs -r rm -rf

echo "backup done: $OUT"
ls -lh "$OUT"
