# hamyar-crm — crm.hamyar.co (vtiger CRM 8.4)

Deployment for the company CRM. **This directory is both the repo and the live
deployment** (`/opt/hamyar-crm` on the Hamyar VPS, 212.38.94.166). Moved here on
2026-09-23 from its own box, `srv004` / `185.112.151.120` (Ubuntu 22.04 + CloudPanel).

```
/opt/hamyar-crm
├── docker-compose.yml   project `hamyar-crm`: db (mariadb 10.11) + crm (php 8.3 + apache)
├── Dockerfile           → image hamyar-crm:8.3
├── php.ini apache.conf  baked into the image
├── cutover.sh           the final switch-over from srv004
├── .env                 CRM_DB_NAME/USER/PASS/ROOT          ← not in git
├── html/                the vtiger tree, bind-mounted at /var/www/html   ← not in git
├── pcg/                 → /home/hamyar-crm in the container             ← not in git
└── migrate/ backups/    dumps                                           ← not in git
```

`html/` and `pcg/` stay out of git on purpose: 408 MB of vendor code of which about
2000 files are encrypted and licence-locked by **PersianCRM / PersianGroup**, plus the
licence itself. Not ours to push anywhere. They are restored from srv004 or from
`backups/`.

The nginx vhost lives in the **hamyar-server** repo at
`nginx/sites-available/crm.hamyar.co` (same as tools/pulse) and proxies to
`127.0.0.1:8081`.

## Everyday

```bash
cd /opt/hamyar-crm
docker compose ps
docker compose logs -f crm
docker compose up -d --build crm      # after touching Dockerfile / php.ini / apache.conf
```

## The PCG trap

`config.inc.php` lines 2–3 point at `/home/hamyar-crm/pcg-guard.php` (the loader) and
`/home/hamyar-crm/.pcg/license.php` (locked to the domain `crm.hamyar.co`, no expiry).
Rather than patching those paths, `pcg/` is bind-mounted at `/home/hamyar-crm` so they
resolve unchanged. **Without that mount every page is blank** — silently, with nothing
in any log.

## The other trap

vtiger renders an empty body unless it believes the request is https, so the vhost sends
`X-Forwarded-Proto: https` unconditionally. A white page with `Content-Length: 1` means
that header got lost.

## Cutover

`cutover.sh` re-dumps srv004, syncs the files, restores, and turns the 10-minute vtiger
cron on here (and off there). Everything on this server is overwritten — srv004 stays the
source of truth until the Cloudflare record moves. See the header of the script.
