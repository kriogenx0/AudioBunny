#!/bin/bash
# One-time, app-specific setup: this app's database on your managed MySQL
# instance. Everything else (nginx, certbot, Docker, the deploy account,
# the shared sudoers grant) is handled generically by ~/Sites/server-config's
# bootstrap.sh (run once per host) — see web/DEPLOY.md's "Deploy" section.
#
# Matches ~/Sites/pocketproducer-web's deploy/server_setup.sh, adapted to a
# single production database (this app has no separate Action Cable DB).
set -e

read -p "Managed MySQL host (e.g. db-mysql-nyc3-xxxxx-do-user-NNNNNN-0.b.db.ondigitalocean.com): " DB_HOST
read -p "Port [25060]: " DB_PORT
DB_PORT=${DB_PORT:-25060}
read -p "Admin username (e.g. doadmin): " DB_USER
read -s -p "Password for $DB_USER (must match what you'll set as DATABASE_PASSWORD in GitHub Actions): " DB_PW
echo

# Requires this machine's IP to be in the cluster's Trusted Sources in your
# cloud provider's control panel, or this will hang/time out.
command -v mysql >/dev/null 2>&1 || { echo "mysql client required (e.g. brew install mysql-client, or apt-get install mysql-client)"; exit 1; }

MYSQL_PWD="${DB_PW}" mysql \
  -h "$DB_HOST" -P "$DB_PORT" \
  -u "$DB_USER" --ssl-mode=REQUIRED \
  -e "CREATE DATABASE IF NOT EXISTS audiobunny_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "Done."
