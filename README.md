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

## Never upgrade vtiger

The company bought the Persian localisation from a vendor who **encrypted parts of the
code**, and warned that updating vtiger will break the install. That matches what is on
disk: ~2000 PCG-encrypted files scattered through `modules/`, `include/` and `layouts/`,
which no upstream release knows about. So:

- no vtiger version upgrade, no "update" from inside Settings,
- no `composer update`, no replacing files from a vanilla 8.4 tarball,
- module changes only through the vendor, or by editing files that are *not* encrypted.

The encrypted files also cannot be re-downloaded from anywhere — the nightly backup below
is the only copy. Treat it as such.

## Backups

`backup.sh` → `/root/backups/crm/<stamp>/` : `database.sql.gz`, `html.tar.gz` (the whole
vtiger tree), `deploy.tar.gz` (the PCG loader + licence + this deployment's files),
`SHA256SUMS`. Last 7 kept, nightly at 01:30 UTC via `/etc/cron.d/hamyar-crm-backup`,
log in `/var/log/hamyar-crm-backup.log`.

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

## The cron trap

`vtigercron.php` only does anything when `php_sapi_name()` is `fpm-fcgi` (srv004 was
php-fpm) or it is a CLI call with `SERVER_SOFTWARE` set. This container is
`apache2handler`, so calling it over http answers **200 in 18 ms having run nothing**.
`/etc/cron.d/hamyar-crm` therefore goes through `docker exec … php -f vtigercron.php`,
logging to `/var/log/hamyar-crm-cron.log`.

## Developing on this install

`docs/vtiger-development.md` — the vtiger developer guide distilled and checked against
this install: request routing, module layout, records and the database, event handlers,
cron, the webservice API, vtlib, templates. It opens with a map of exactly which parts of
the tree are PCG-encrypted (short version: the vtiger core is stock and safe; the paid
`*4You` modules and the fa_ir language files are not).

## Cutover

`cutover.sh` re-dumps srv004, syncs the files, restores, and turns the 10-minute vtiger
cron on here (and off there). Everything on this server is overwritten — srv004 stays the
source of truth until the Cloudflare record moves. See the header of the script.

## Documentation

This project follows the Hamyar documentation standard (`/var/www/hamyar-docs/docs/STANDARD.md`,
readable at docs.hamyar.co → راهنما): `README.md` + `docs/` with `title`/`type` front matter
(tutorial · howto · reference · explanation · adr · changelog), docs updated in the same commit as the
behaviour they describe, a line in the CHANGELOG, an ADR in `docs/adr/` for each real decision, and
commit bodies that say **why**. Nothing secret in docs or commits. After a push the hub
(docs.hamyar.co) picks the docs up and sends the owner a Persian note of what changed and why.
