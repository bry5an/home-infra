# home-infra

systemd units + nginx config for home-grown web apps on `media` (LAN-only, no internet exposure). Each site gets:

1. A systemd unit in `systemd/` that runs it and restarts it on boot/crash.
2. An mDNS alias (`<name>.local`) published via the `avahi-alias@.service` template, listed in `aliases.txt`.
3. An nginx vhost in `nginx/sites-available/` that proxies `<name>.local` to the app's `127.0.0.1:<port>` and restricts access to private LAN ranges (`nginx/snippets/lan-only.conf`).

nginx is the only thing allowed to listen on a LAN-facing port (80); every backend app binds to `127.0.0.1` only.

## Deploying

```bash
git -C ~/git/home-infra pull
sudo bash ~/git/home-infra/deploy.sh
```

`deploy.sh` is idempotent — installs nginx/avahi-utils if missing, installs/enables every `*.service` in `systemd/` (skipping the `@.` template itself), enables an `avahi-alias@<name>.service` for every line in `aliases.txt`, and syncs `nginx/` into `/etc/nginx/`.

## Adding a new site

1. Add `systemd/<name>.service` (backend app, bound to `127.0.0.1:<port>`).
2. Append `<name>` to `aliases.txt`.
3. Add `nginx/sites-available/<name>.local.conf`, proxying to that port, with `include snippets/lan-only.conf;`.
4. Commit, push, then on the server: `git pull && sudo bash deploy.sh`.

## Sites

| Alias | Backend | Port | Source |
|---|---|---|---|
| epub.local | `epub-library.service` | 8000 | `~/git/jp-audiobooks/epub-library` |

Jellyfin (`:8096`) predates this repo and still runs as its own `jellyfin.service` installed by its apt package — not managed here.

## One-time migration notes

`epub-library` used to run as a bare `uv run cli.py serve` under `nohup`, bound to `0.0.0.0:8000` (directly LAN-exposed, no boot start). Migrating it to this setup required, once:

```bash
pkill -u bryan -f 'cli.py serve'   # stop the ad-hoc process
# edit epub-library/config.prod.toml: host = "0.0.0.0" -> host = "127.0.0.1"
```

`deploy.sh` then takes over starting it via systemd. Any *new* site should be written to bind `127.0.0.1` from the start.
