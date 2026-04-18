"""
AudioBunny deployment — Fabric 2 (Capistrano-style)

Usage:
    fab -H deploy@audiobunny.example.com deploy
    fab -H deploy@audiobunny.example.com deploy --branch=feature/xyz
    fab -H deploy@audiobunny.example.com rollback

Install locally:
    pip install -r deploy/requirements.txt

Server prerequisites (run once via `fab setup`):
    - Ubuntu 22.04 / Debian 12
    - Python 3.11+, Node 20+, nginx, git installed
    - A 'deploy' user with sudo rights for systemctl/nginx reload
    - SSH key of the deploying machine added to ~deploy/.ssh/authorized_keys

Directory layout on server:
    /var/www/audiobunny/
        releases/           <- timestamped release dirs
            20240101120000/
                api/
                frontend/
        shared/             <- persisted across releases
            audiobunny.db
            thumbnails/
            downloads/
        current -> releases/20240101120000   <- symlink
        venv/               <- shared Python virtualenv
"""

from __future__ import annotations

import os
from datetime import datetime, timezone

from fabric import task, Connection
from invoke import run as local_run

# ── Configuration ─────────────────────────────────────────────────────────────

REPO          = "git@github.com:your-org/audiobunny.git"
DEPLOY_PATH   = "/var/www/audiobunny"
RELEASES_PATH = f"{DEPLOY_PATH}/releases"
SHARED_PATH   = f"{DEPLOY_PATH}/shared"
CURRENT_LINK  = f"{DEPLOY_PATH}/current"
VENV          = f"{DEPLOY_PATH}/venv"
PIP           = f"{VENV}/bin/pip"
SERVICE_NAME  = "audiobunny-api"
KEEP_RELEASES = 5   # how many old releases to retain


# ── Helpers ───────────────────────────────────────────────────────────────────

def _release_path(ts: str) -> str:
    return f"{RELEASES_PATH}/{ts}"


def _run(c: Connection, cmd: str, **kw):
    """Run a remote command, echoing it first."""
    print(f"  → {cmd}")
    return c.run(cmd, **kw)


def _sudo(c: Connection, cmd: str, **kw):
    print(f"  ⚡ sudo {cmd}")
    return c.sudo(cmd, **kw)


# ── Tasks ─────────────────────────────────────────────────────────────────────

@task
def setup(c, host=None):
    """
    First-time server provisioning. Run once per server.

        fab -H deploy@audiobunny.example.com setup
    """
    conn = Connection(host or c.host)
    _run(conn, f"mkdir -p {RELEASES_PATH} {SHARED_PATH}/thumbnails {SHARED_PATH}/downloads")
    _run(conn, f"python3 -m venv {VENV}")
    _run(conn, f"{PIP} install --upgrade pip")
    # Clone repo into a bootstrap release so 'current' can be symlinked
    print("Setup complete. Run `fab deploy` to deploy the first release.")


@task
def deploy(c, branch="main", host=None):
    """
    Deploy a new release.

        fab -H deploy@audiobunny.example.com deploy
        fab -H deploy@audiobunny.example.com deploy --branch=staging
    """
    conn = Connection(host or c.host)
    ts   = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    rp   = _release_path(ts)

    print(f"\n=== Deploying branch '{branch}' as release {ts} ===\n")

    # 1. Clone the target branch into a fresh release directory
    _run(conn, f"git clone --depth 1 --branch {branch} {REPO} {rp}")

    # 2. Link shared data into the release
    _run(conn, f"ln -sfn {SHARED_PATH}/audiobunny.db {rp}/web/api/audiobunny.db")
    _run(conn, f"ln -sfn {SHARED_PATH}/thumbnails    {rp}/web/api/thumbnails")
    _run(conn, f"ln -sfn {SHARED_PATH}/downloads     {rp}/web/api/downloads")

    # 3. Install Python dependencies
    _run(conn, f"{PIP} install -q -r {rp}/web/api/requirements.txt")

    # 4. Build the React frontend
    _run(conn, f"cd {rp}/web/frontend && npm ci --prefer-offline")
    _run(conn, f"cd {rp}/web/frontend && npm run build")

    # 5. Flip the 'current' symlink atomically
    _run(conn, f"ln -sfn {rp} {CURRENT_LINK}")

    # 6. Restart API, reload nginx
    _sudo(conn, f"systemctl restart {SERVICE_NAME}")
    _sudo(conn, "nginx -s reload")

    # 7. Prune old releases
    _prune_releases(conn)

    print(f"\n✓ Release {ts} is live.\n")


@task
def rollback(c, host=None):
    """
    Roll back to the previous release.

        fab -H deploy@audiobunny.example.com rollback
    """
    conn = Connection(host or c.host)
    result = _run(conn, f"ls -1t {RELEASES_PATH}", hide=True)
    releases = result.stdout.strip().splitlines()
    if len(releases) < 2:
        print("No previous release to roll back to.")
        return
    previous = _release_path(releases[1])
    print(f"\n=== Rolling back to {releases[1]} ===\n")
    _run(conn, f"ln -sfn {previous} {CURRENT_LINK}")
    _sudo(conn, f"systemctl restart {SERVICE_NAME}")
    _sudo(conn, "nginx -s reload")
    print(f"\n✓ Rolled back to {releases[1]}.\n")


@task
def status(c, host=None):
    """
    Show current release and service status.

        fab -H deploy@audiobunny.example.com status
    """
    conn = Connection(host or c.host)
    _run(conn, f"readlink {CURRENT_LINK}")
    _run(conn, f"systemctl status {SERVICE_NAME} --no-pager -l", warn=True)


@task
def logs(c, lines=50, host=None):
    """
    Tail the API service logs.

        fab -H deploy@audiobunny.example.com logs --lines=100
    """
    conn = Connection(host or c.host)
    _run(conn, f"journalctl -u {SERVICE_NAME} -n {lines} --no-pager")


# ── Internal helpers ──────────────────────────────────────────────────────────

def _prune_releases(conn: Connection):
    result = _run(conn, f"ls -1t {RELEASES_PATH}", hide=True)
    releases = result.stdout.strip().splitlines()
    for old in releases[KEEP_RELEASES:]:
        _run(conn, f"rm -rf {RELEASES_PATH}/{old}")
        print(f"  pruned old release: {old}")
