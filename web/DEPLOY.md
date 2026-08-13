# Deploying audio-bunny.com

Deploys via **GitHub Actions** (`.github/workflows/deploy.yml`) to
`audio-bunny.com`, a shared Ubuntu box (`104.131.183.186`, `ssh general`)
that also hosts several other sites under the same `deploy` account. Every
push to `main` that touches `web/**`: builds the React app, builds the
Rails API's Docker image (`web/Dockerfile.rails`'s `production` stage),
streams the compressed image over SSH into `docker load` on the host, then
runs `web/deploy/deploy.sh`. The script copies the React build for nginx to
serve and starts Rails behind `/api`. The database is an **external managed
MySQL instance** (not co-located with the app — this VPS only has ~965MB
RAM and already runs several other sites). No container registry,
Capistrano, Passenger/RVM, or building on the server itself.

This setup — and this file — mirrors `~/Sites/pocketproducer-web` (same
repo owner's other Rails app, on this same VPS) almost exactly. If
something here is unclear, that repo's README "Deploy" section and its
`deploy/` scripts are the reference implementation.

`~/Sites/server-config` is **bootstrapping-only** — it installs
Docker/nginx/certbot, creates the shared `deploy` account and its narrow
sudoers grant, and ships the nginx snippets every vhost includes. It never
touches this app's own directory, nginx vhost, or certs; `web/deploy/deploy.sh`
in this repo owns all of that (compose file, `.env`, container lifecycle,
this app's nginx vhost, its own `certbot` call), per that repo's README
"Conventions for per-app deploy scripts".

## One-time setup

1. `web/deploy/server_setup.sh` — creates this app's production database on
   your managed MySQL instance (needs a `mysql` client locally; no SSH/sudo
   required). Requires the machine running it to be in that instance's
   allowed/trusted source list, or it'll hang trying to connect.
2. Install this app's narrow sudoers grant on the server, by hand, as
   `admin` — see `web/deploy/server/sudoers.d/audio-bunny-com`'s own header
   for the exact commands. This is on top of the shared grant
   `~/Sites/server-config`'s `bootstrap.sh` installs for `deploy`, and
   covers only this app's own vhost content and its one `certbot`
   invocation.
3. In Settings → Secrets and variables → Actions, add the repository
   secrets `DEPLOY_SSH_KEY` (a private key whose public half is authorized
   on the `deploy` account), `SECRET_KEY_BASE` (`bin/rails secret`
   locally), `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`, and `JWT_SECRET`
   (signs the app's JWTs — see `rails/lib/jwt_service.rb`; generate with
   e.g. `ruby -rsecurerandom -e "puts SecureRandom.hex(64)"`). Optionally
   add `DB_PORT` (defaults to `3306`), `DB_NAME` (defaults to
   `audiobunny_production`), and `RAILS_ENV` (defaults to `production`) as
   repository variables. The workflow passes only this explicit allowlist
   to `web/deploy/deploy.sh`, which replaces the host's mode-`0600` `.env`
   on every run.
4. Push to `main` (or run the workflow manually) — this first run transfers
   the image, brings up the container, picks and persists a `HOST_PORT`,
   installs an HTTP-only vhost, requests the TLS cert via
   `certbot certonly --webroot`, then swaps in the full HTTPS vhost. See
   `web/deploy/deploy.sh`'s own header for the exact bootstrap order and why
   it matters (nginx can't reload with a vhost pointing at cert files that
   don't exist yet).

## Ongoing deploys

Just push to `main` (touching `web/**`) — the workflow transfers
`audio-bunny-com-api:latest` and the React build, then `web/deploy/deploy.sh`
re-runs in full. To run the script by hand, first load that image onto the
host and build `web/frontend/dist`, then run:

```bash
SECRET_KEY_BASE=$(cd web/rails && bin/rails secret) \
DB_HOST=your-db-host DB_USERNAME=... DB_PASSWORD=... JWT_SECRET=... \
  web/deploy/deploy.sh
```

## Rollback

No automated rollback command. GitHub Actions only ever ships whatever's
currently on `main`, so to roll back, revert the commit (or re-run the
workflow against an older one) and push — CI rebuilds and re-ships that
version in full.

## Local development

See the repo root `Makefile` / `web/docker-compose.yml` — local dev runs
its own `mysql` container (this file only covers production, which
doesn't).
