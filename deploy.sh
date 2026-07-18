#!/bin/bash
# Idempotent: safe to re-run after adding a new site's files to this repo.
#   git -C ~/git/home-infra pull
#   sudo bash ~/git/home-infra/deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash deploy.sh" >&2
  exit 1
fi

echo "== Installing nginx + avahi-utils =="
apt-get update
apt-get install -y nginx avahi-utils

echo "== Installing avahi alias helper script =="
install -o bryan -g bryan -m 755 -D scripts/avahi-alias.sh /home/bryan/bin/avahi-alias.sh

echo "== Installing systemd units =="
install -m 644 systemd/*.service /etc/systemd/system/
systemctl daemon-reload

echo "== Enabling backend services =="
for svc in systemd/*.service; do
  name=$(basename "$svc")
  [[ "$name" == *"@."* ]] && continue  # templates aren't started directly
  systemctl enable --now "$name"
done

echo "== Enabling mDNS aliases (aliases.txt) =="
if [[ -f aliases.txt ]]; then
  while read -r alias; do
    [[ -z "$alias" ]] && continue
    systemctl enable --now "avahi-alias@${alias}.service"
  done < aliases.txt
fi

echo "== Installing nginx config =="
mkdir -p /etc/nginx/snippets
install -m 644 nginx/snippets/*.conf /etc/nginx/snippets/
install -m 644 nginx/sites-available/* /etc/nginx/sites-available/
for f in nginx/sites-available/*; do
  name=$(basename "$f")
  ln -sf "/etc/nginx/sites-available/$name" "/etc/nginx/sites-enabled/$name"
done
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable --now nginx
systemctl reload nginx

echo
echo "== Status =="
systemctl --no-pager --lines=3 status nginx || true
for svc in systemd/*.service; do
  name=$(basename "$svc")
  [[ "$name" == *"@."* ]] && continue
  systemctl --no-pager --lines=3 status "$name" || true
done

echo
echo "Done. Test from the server:"
echo "  curl -H 'Host: epub.local' http://localhost/"
echo "Test from a Mac/Linux machine on the LAN:"
echo "  curl http://epub.local/"
