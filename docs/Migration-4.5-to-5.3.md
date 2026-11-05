# Migrating an Existing Moodle 4.5 Site to Moodle 5.3 on Azure

This document provides an overview of how to migrate an existing
Moodle 4.5 site (database + moodledata) into a Moodle cluster deployed
on Azure running Moodle 5.3, and how to bring the migrated content up
to the deployed code version. It is based on a verified migration of
this exact scenario.

Only the **database and moodledata files** are migrated by this
process. The Moodle code stays as deployed by the template. Add-on
plugin code is not migrated automatically — see [Migrating add-on
plugins](#migrating-add-on-plugins-workplace-certificates) below for
installing the Moodle Workplace certificate plugins on the target.

## Prerequisites

In order to configure our deployment and tools we'll set up some
[environment variables](./Environment-Variables.md) to ensure consistency.

In order to migrate a site it is clearly necessary to first [deploy a
scalable Moodle cluster on Azure](./Deploy.md).

**IMPORTANT NOTE**

This guide assumes the target is a **fresh deployment of all
components in a new resource group** — a newly deployed controller VM,
web frontends, database server, Redis cache and file share that have
not served production traffic and hold no data worth keeping. Do not
run this migration against a resource group with an existing,
in-service Moodle installation: Step 2 replaces the entire target
database and Step 3 overlays moodledata, destroying whatever was there
before.

For convenience and readability this document also assumes that
essential [deployment details for your cluster have been assigned to
environment variables](./Get-Install-Data.md).

In addition you will need the source site artifacts:

* `source-db.sql.gz` — a `mysqldump` of the source Moodle 4.5 database
* the source `moodledata/filedir` directory (plus `lang/` if customized)

All commands below run **on the controller VM** (for example via
Bastion or `az vm run-command invoke -g $MOODLE_RG_NAME -n
<controller-vm>`), as root unless noted. The database credentials for
the target cluster are in `/moodle/html/moodle/config.php` (`dbhost`,
`dbuser`, `dbpass`).

## Important rules before you begin

1. **Never unzip a source Moodle code tree over
   `/moodle/html/moodle`.** The Moodle 5.x layout is:
   * `/moodle/html/moodle/` — root: `config.php`, `admin/cli/` (CLI
     tools), build files
   * `/moodle/html/moodle/public/` — the web root (`$CFG->dirroot`),
     served by the web server

   Only the database and moodledata files migrate. The code stays as
   deployed.
2. **Never copy the source `config.php`** — the target one has the
   correct database, Redis, Azure Files and proxy settings. Merge
   individual custom settings by hand if needed.
3. **Never copy source caches**: skip `muc/`, `cache/`, `localcache/`,
   `sessions/`, `temp/` and `trashdir/` from the source
   moodledata. A copied `muc/config.php` will point Moodle at the
   *source* Redis and break every request.
4. The source Moodle major version must be upgrade-compatible with 5.3
   (4.2 or later is recommended; this guide assumes 4.5). Upgrade the
   source first if it is older.

## Step 1 — Enable maintenance mode and take a safety backup

```bash
sudo -u www-data php /moodle/html/moodle/admin/cli/maintenance.php --enable
mysqldump -h <mysql-host> -u <dbuser> -p'<dbpass>' --single-transaction --databases moodle \
  | gzip > /moodle/db-backup-pre-migration.sql.gz
```

## Step 2 — Import the source database

```bash
gunzip < source-db.sql.gz | mysql -h <mysql-host> -u <dbuser> -p'<dbpass>' moodle
```

## Step 3 — Copy the moodledata content

Copy **only** user content — exclude every cache and session
directory:

```bash
rsync -a \
  --exclude=muc --exclude=cache --exclude=localcache \
  --exclude=sessions --exclude=temp --exclude=trashdir --exclude=lock \
  <source-moodledata>/ /moodle/moodledata/
chown -R www-data:www-data /moodle/moodledata
```

**IMPORTANT NOTE**

Do **not** overwrite `/moodle/moodledata/muc/config.php` — the
deployed one points at this environment's Redis cache. A copied source
`muc/config.php` will break every web request.

## Step 4 — Run the upgrade (4.5 → 5.3)

```bash
cd /tmp
sudo -u www-data php /moodle/html/moodle/admin/cli/upgrade.php --non-interactive
```

If it aborts with `Outdated component cache file`, rebuild the
component cache first and then rerun the upgrade:

```bash
rm -f /var/www/html/moodle/core_component.php
sudo -u www-data php /moodle/html/moodle/admin/cli/alternative_component_cache.php --rebuild
```

## Step 5 — Purge caches and disable maintenance mode

```bash
sudo -u www-data php /moodle/html/moodle/admin/cli/purge_caches.php
sudo -u www-data php /moodle/html/moodle/admin/cli/maintenance.php --disable
rm -rf /tmp/localcachedir
systemctl restart php8.3-fpm nginx varnish
```

## Step 6 — Propagate code and caches to the web frontends

As described in [the management documentation](./Manage.md#updating-moodle-codesettings),
the web frontends keep a local copy of the Moodle code. After a
migration the local copies and their component caches must be
refreshed.

On the **controller** VM:

```bash
/usr/local/bin/update_last_modified_time.moodle_on_azure.sh
```

On **each** web frontend instance (for example `az vmss run-command
invoke ... --instance-id <id>`):

```bash
/usr/local/bin/sync_moodle_html_local_copy_if_modified.sh
rm -f /var/www/html/moodle/core_component.php
sudo -u www-data php /var/www/html/moodle/admin/cli/alternative_component_cache.php --rebuild
rm -rf /tmp/localcachedir
systemctl restart php8.3-fpm nginx varnish
```

**IMPORTANT NOTE**

Rebuild the component cache (classmap) from each node's **local**
tree, not the shared one — shared-tree paths in the classmap cause
`Cannot declare class ...` fatal errors on web requests.

## Step 7 — Verify the migration

```bash
# On a web frontend — expect 200 and the login page title
curl -s "http://localhost:81/login/index.php" \
  -H 'X-Forwarded-Proto: https' -H "Host: $MOODLE_SITE_HOSTNAME" \
  -o /tmp/v.html -w '%{http_code}\n'
grep -io '<title>[^<]*' /tmp/v.html

# Public URL — expect 200 and no maintenance text
curl -skL "https://$MOODLE_SITE_HOSTNAME/" -o /tmp/pub.html -w '%{http_code}\n'
```

Results:

```expected_similarity=0.4
200
<title>Log in to the site
200
```

Then log in as an administrator and check *Site administration →
Notifications* and the plugins overview page.

## Migrating add-on plugins (Workplace certificates)

The database import and moodledata copy move the certificate **data**,
but the certificate **plugin code** is not installed on the target
deployment, so templates, issued certificates and the course
activities will be invisible until the plugins are installed. The
plugins involved are maintained by Moodle HQ and are LMS-compatible:

| Plugin | Frankenstyle | Install path (5.x `public/` layout) |
|---|---|---|
| Workplace certificate manager | `tool_certificate` | `/moodle/html/moodle/public/admin/tool/certificate` |
| Workplace course certificate | `mod_coursecertificate` | `/moodle/html/moodle/public/mod/coursecertificate` |

`mod_coursecertificate` depends on `tool_certificate` — always
install/upgrade `tool_certificate` first and keep both plugins on the
same release train.

### Check the plugin versions the migrated database expects

The code you install must be the same version or **newer** than the
version recorded in the migrated database, otherwise Moodle refuses to
start the plugins ("downgrade detected"):

```bash
mysql -h <mysql-host> -u <dbuser> -p'<dbpass>' moodle -e \
  "SELECT plugin, value AS db_version FROM mdl_config_plugins
   WHERE plugin IN ('tool_certificate','mod_coursecertificate') AND name='version';"
```

Check the [tool_certificate](https://marketplace.moodle.com/plugins/tool_certificate/versions)
and [mod_coursecertificate](https://marketplace.moodle.com/plugins/mod_coursecertificate/versions)
version pages for a release that supports your target Moodle version.
If the newest release only declares support for an older Moodle
version, installation still proceeds as long as the plugin's
`$plugin->requires` is satisfied (undeclared support produces only a
warning) — but smoke-test thoroughly before declaring success.

**IMPORTANT NOTE**

In this example the plugin releases that replace the 4.5-compatible
versions (the `MOODLE_500_STABLE` 5.0.x releases used below) only
declare support up to **Moodle 5.2**. The Workplace developers (Moodle
HQ) make **no compatibility claim for Moodle 5.3**. They were found to
work on a Moodle 5.3 target during this migration, but they have
**not been exhaustively tested** on 5.3 — treat them as working at
your own risk, run the verification checklist below immediately after
installing, and check the Marketplace version pages above for a
release that officially declares 5.3 support before executing.

### Download and install the plugin code

Download pinned versions from the official GitHub repositories (the
Marketplace download URLs are not reliably fetchable with `curl`):

```bash
cd /tmp && rm -f *.zip
curl -fLo tool_certificate.zip \
  "https://github.com/moodleworkplace/moodle-tool_certificate/archive/refs/heads/MOODLE_500_STABLE.zip"
curl -fLo mod_coursecertificate.zip \
  "https://github.com/moodleworkplace/moodle-mod_coursecertificate/archive/refs/heads/MOODLE_500_STABLE.zip"
file *.zip   # both must report "Zip archive data"

unzip -q tool_certificate.zip && unzip -q mod_coursecertificate.zip
mv moodle-tool_certificate-MOODLE_500_STABLE certificate
mv moodle-mod_coursecertificate-MOODLE_500_STABLE coursecertificate
```

Install the code into the shared tree. Plugins go into their own
subdirectories under `public/` — never unzip anything over the
root. Use `cp` + `rm` rather than `mv` because `/tmp` (local disk) and
`/moodle` (Azure Files) are different filesystems:

```bash
sudo mkdir -p /moodle/html/moodle/public/admin/tool/certificate \
              /moodle/html/moodle/public/mod/coursecertificate
sudo cp -a /tmp/certificate/.       /moodle/html/moodle/public/admin/tool/certificate/
sudo cp -a /tmp/coursecertificate/. /moodle/html/moodle/public/mod/coursecertificate/
sudo chown -R www-data:www-data /moodle/html/moodle/public/admin/tool/certificate \
                                /moodle/html/moodle/public/mod/coursecertificate
sudo rm -rf /tmp/certificate /tmp/coursecertificate /tmp/*.zip

# Sanity check: version.php must be at the top level of each plugin directory
ls /moodle/html/moodle/public/admin/tool/certificate/version.php \
   /moodle/html/moodle/public/mod/coursecertificate/version.php
```

### Upgrade, propagate and verify

Repeat Steps 1, 4, 5 and 6 above (maintenance mode, upgrade,
cache purge, propagation to the web frontends). Because the migrated
database already holds the source plugin versions, Moodle runs the
plugins' own upgrade steps against the existing tables — the migrated
templates and issued certificates are preserved, not recreated.

Finally verify:

1. *Site administration → Plugins → Plugins overview*: both plugins
   listed, no "missing from disk"
2. *Site administration → Certificates → Manage certificate
   templates*: migrated templates render with their images
3. Open a course with a Course certificate activity and download a PDF
   as a test student
4. The verification (QR) link on a pre-migration certificate validates
   on the public URL
5. Cron runs error-free:
   `sudo -u www-data php /moodle/html/moodle/admin/cli/cron.php`

## Rolling back

The Step 1 backup allows a full rollback of the database:

```bash
sudo -u www-data php /moodle/html/moodle/admin/cli/maintenance.php --enable
gunzip < /moodle/db-backup-pre-migration.sql.gz | mysql -h <mysql-host> -u <dbuser> -p'<dbpass>'
sudo -u www-data php /moodle/html/moodle/admin/cli/purge_caches.php
sudo -u www-data php /moodle/html/moodle/admin/cli/maintenance.php --disable
```

To remove the certificate plugin code without touching the migrated
data (the data stays in the database and filedir):

```bash
rm -rf /moodle/html/moodle/public/admin/tool/certificate \
       /moodle/html/moodle/public/mod/coursecertificate
sudo -u www-data php /moodle/html/moodle/admin/cli/purge_caches.php
```

Then repeat the classmap rebuild and service restarts on the
controller and all web frontends (Step 6).
