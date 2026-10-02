# home-infra

Ansible playbook for home-grown web apps on `media` (LAN-only, no internet exposure). One role, `webhost`, parameterized over the `sites` list in `group_vars/all.yml`. For each site it manages:

1. A systemd unit that runs it and restarts it on boot/crash.
2. An mDNS alias (`<name>.local`) published via the `avahi-alias@.service` template.
3. An nginx vhost proxying `<name>.local` to the app's `127.0.0.1:<port>`, restricted to private LAN ranges.
4. `ufw` rules: port 80 allowed from LAN ranges only; any leftover direct-port rule for the app removed.

nginx is the only thing allowed to listen on a LAN-facing port (80); every backend app binds to `127.0.0.1` only.

## Setup (once per control machine)

```bash
brew install ansible          # or: uv tool install ansible
ansible-galaxy collection install -r requirements.yml
```

Requires `~/.ssh/config` to have a `media` host entry (already the case on this Mac). Ansible shells out to system `ssh`, so no separate credentials setup is needed.

## Running

```bash
cd ~/git/home-infra
ansible home -m ping                        # sanity check connectivity
ansible-playbook site.yml --check --diff -K  # dry run, shows what would change
ansible-playbook site.yml -K                 # apply
```

`-K` prompts for the sudo password on `media` (general passwordless sudo is not configured, intentionally — only the narrow command list below). `--check --diff` is the drift-detection story: run it any time to see whether the server has drifted from what's declared here, without changing anything.

## Passwordless sudo (narrow allowlist)

The role installs `/etc/sudoers.d/webhost` (validated with `visudo -cf`) so deploys can restart a site over ssh without a password. It is generated from `sites`, so a renamed or new site is covered automatically on the next `ansible-playbook site.yml -K` — this is what to re-run after renaming a service. Allowed for `bryan`, nothing else:

- `systemctl restart|start|stop <name>` and `<name>.service` for each site (both spellings, since sudo matches arguments literally)
- `systemctl reload nginx`, `systemctl restart nginx`, `nginx -t`
- `systemctl daemon-reload`

Use the full path, e.g. `ssh media 'sudo -n /usr/bin/systemctl restart library'`. Not included on purpose: `enable`/`disable`, `ufw`, `apt`, and file edits under `/etc`. `journalctl` and `systemctl status` need no sudo.

## Adding a new site

1. Append an entry to `sites` in `group_vars/all.yml` (name, description, workdir, exec_start, port, environment). New sites should bind their app to `127.0.0.1:<port>` from the start — never `0.0.0.0`.
2. `ansible-playbook site.yml --check --diff -K` to preview, then `ansible-playbook site.yml -K` to apply.

No new files needed for a typical site — the role templates the systemd unit and nginx vhost from the `sites` list.

## Sites

| Alias | Backend | Port | Source |
|---|---|---|---|
| epub.local | `epub-library.service` (from `sites: name: epub`) | 8000 | `~/git/jp-audiobooks/epub-library` |

Jellyfin (`:8096`) predates this repo and still runs as its own `jellyfin.service` installed by its apt package, with its own pre-existing `ufw` rule — not managed here.

## History

Originally a hand-rolled bash `deploy.sh` (see git history before the Ansible rewrite). Moved to Ansible for `--check` drift detection and because the bash version silently missed a `ufw` rule for port 80 on first deploy — the kind of gap idempotent, declarative modules catch instead of hide.

`epub-library` itself was migrated once, by hand, from a bare `nohup uv run cli.py serve` (bound to `0.0.0.0:8000`, no boot start) to this setup — that migration is done and isn't part of the normal playbook run.
