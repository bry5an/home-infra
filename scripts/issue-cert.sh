#!/bin/sh
# Issues one mkcert leaf cert covering <name>.local for every entry in `sites`.
# Re-run after adding a site, then `ansible-playbook site.yml -K`.
# One-time per device: install the CA root (`mkcert -CAROOT`/rootCA.pem). On this
# Mac: `mkcert -install`.
set -eu
cd "$(dirname "$0")/.."
names=$(ansible localhost -e @group_vars/all.yml -m debug \
  -a 'msg={{ sites | map(attribute="name") | map("regex_replace", "$", ".local") | join(" ") }}' \
  | sed -n 's/.*"msg": "\(.*\)".*/\1/p')
[ -n "$names" ] || { echo "no site names found" >&2; exit 1; }
mkdir -p certs
echo "issuing for: $names"
# shellcheck disable=SC2086
mkcert -cert-file certs/webhost.pem -key-file certs/webhost-key.pem $names
