#!/bin/bash
# Deploys audio-bunny.com to production end to end: copies the built React
# app and compose file, writes .env, brings up the api container, and
# installs this app's own nginx vhost + TLS cert. Run from CI
# (.github/workflows/deploy.yml) or by hand — either way it just SSHes/SCPs
# to deploy@audio-bunny.com; no other tooling required. CI loads
# audio-bunny-com-api:latest onto the host before running this script. Safe
# to re-run.
#
# Matches ~/Sites/pocketproducer-web's deploy/deploy.sh (same repo owner's
# other Rails app on this VPS) almost exactly — see web/DEPLOY.md.
#
# ~/Sites/server-config is bootstrapping-only (installs Docker/nginx/
# certbot, creates the deploy account + its shared sudoers grant, ships the
# nginx snippets this vhost includes) — this script owns everything
# specific to *this* app.
#
# Needs, on top of the shared sudoers grant bootstrap.sh installs: the
# per-app grant at deploy/server/sudoers.d/audio-bunny-com (installed once,
# by hand, as admin — see that file's own header).
#
# SECRET_KEY_BASE must be set in the environment when this runs (CI: the
# SECRET_KEY_BASE repo secret; by hand: export it yourself, e.g.
# `SECRET_KEY_BASE=$(bin/rails secret) DATABASE_HOST=... deploy/deploy.sh`).
set -euo pipefail

: "${SECRET_KEY_BASE:?SECRET_KEY_BASE must be set in the environment}"
: "${DB_HOST:?DB_HOST must be set in the environment}"

SSH_TARGET="deploy@audio-bunny.com"
DOMAIN="audio-bunny.com"
REMOTE_DIR="/var/www/$DOMAIN"
CERTBOT_EMAIL="simplex0@gmail.com"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WEB_DIST="$SCRIPT_DIR/../frontend/dist"
CERTBOT_CMD="sudo -n /usr/bin/certbot certonly --webroot -w /var/www/certbot -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m $CERTBOT_EMAIL"

if [ ! -f "$WEB_DIST/index.html" ]; then
  echo "frontend/dist is missing; run 'npm --prefix ../frontend ci && npm --prefix ../frontend run build' first" >&2
  exit 1
fi

echo "==> Ensuring $REMOTE_DIR exists"
ssh "$SSH_TARGET" "sudo -n /usr/bin/mkdir -p '$REMOTE_DIR' && sudo -n /bin/chown deploy:deploy '$REMOTE_DIR'"

echo "==> Copying compose file"
scp "$SCRIPT_DIR/../docker-compose.prod.yml" "$SSH_TARGET:$REMOTE_DIR/docker-compose.yml"

echo "==> Copying web app"
COPYFILE_DISABLE=1 tar -C "$WEB_DIST" -czf - . | ssh "$SSH_TARGET" "mkdir -p '$REMOTE_DIR/web' && tar -C '$REMOTE_DIR/web' -xzf -"

echo "==> Picking (or reusing) a host port"
HOST_PORT=$(ssh "$SSH_TARGET" bash -s -- "$REMOTE_DIR" <<'REMOTE'
set -e
cd "$1"
port=$(grep -m1 '^HOST_PORT=' .env 2>/dev/null | cut -d= -f2 | sed 's/[^0-9]//g' || true)
if [ -z "$port" ]; then
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
fi
echo "$port"
REMOTE
)
echo "    HOST_PORT=$HOST_PORT"

write_env_var() {
  local NAME="$1"
  local VALUE="$2"
  [ -z "$VALUE" ] && return
  if [[ "$VALUE" == *$'\n'* || "$VALUE" == *$'\r'* ]]; then
    echo "$NAME must be a single-line value" >&2
    exit 1
  fi
  # Compose env files treat single-quoted values literally. Escape the two
  # characters that can otherwise terminate or alter that representation.
  VALUE=${VALUE//\\/\\\\}
  VALUE=${VALUE//\'/\\\'}
  printf "%s='%s'\n" "$NAME" "$VALUE"
}

echo "==> Writing runtime secrets and variables to .env"
{
  write_env_var RAILS_ENV "${RAILS_ENV:-production}"
  write_env_var SECRET_KEY_BASE "$SECRET_KEY_BASE"
  write_env_var DB_HOST "$DB_HOST"
  write_env_var DB_PORT "${DB_PORT:-3306}"
  write_env_var DB_USERNAME "${DB_USERNAME:-}"
  write_env_var DB_PASSWORD "${DB_PASSWORD:-}"
  write_env_var DB_NAME "${DB_NAME:-audiobunny_production}"
  write_env_var JWT_SECRET "${JWT_SECRET:-}"
  write_env_var HOST_PORT "$HOST_PORT"
} | ssh "$SSH_TARGET" "umask 077; cat > '$REMOTE_DIR/.env'; chmod 600 '$REMOTE_DIR/.env'"

echo "==> Recreating the api container from the image loaded by CI"
ssh "$SSH_TARGET" "cd '$REMOTE_DIR' && docker compose up -d --force-recreate --no-deps --pull never api && docker image prune -f"

install_vhost() {
  local SRC="$1"
  local RENDERED; RENDERED=$(mktemp)
  sed "s/__HOST_PORT__/$HOST_PORT/g" "$SRC" > "$RENDERED"
  scp "$RENDERED" "$SSH_TARGET:/tmp/$(basename "$SRC")"
  rm -f "$RENDERED"
  ssh "$SSH_TARGET" "sudo -n /bin/cp /tmp/$(basename "$SRC") /etc/nginx/sites-available/$DOMAIN && sudo -n /bin/ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN && sudo -n /usr/sbin/nginx -t && sudo -n /bin/systemctl reload nginx"
}

if ssh "$SSH_TARGET" "sudo -n /usr/bin/test -f /etc/letsencrypt/live/$DOMAIN/cert.pem"; then
  echo "==> Cert already exists"
else
  echo "==> No cert yet — installing the HTTP-only bootstrap vhost first"
  install_vhost "$SCRIPT_DIR/server/sites-available/$DOMAIN.bootstrap.conf"

  echo "==> Requesting the cert"
  ssh "$SSH_TARGET" "$CERTBOT_CMD"
fi

echo "==> Installing the full (HTTPS) vhost"
install_vhost "$SCRIPT_DIR/server/sites-available/$DOMAIN.conf"

echo "==> Renewing the cert if due (no-op otherwise — webroot mode never touches the vhost)"
ssh "$SSH_TARGET" "$CERTBOT_CMD"
ssh "$SSH_TARGET" "sudo -n /bin/systemctl reload nginx"

echo "Done. https://$DOMAIN -> 127.0.0.1:$HOST_PORT"
