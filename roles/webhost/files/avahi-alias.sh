#!/bin/sh
# Publishes an mDNS alias "$1.local" pointing at this host's current LAN IPv4.
# Looked up at start time (not hardcoded) so it survives DHCP lease changes on restart.
exec /usr/bin/avahi-publish -a -R "$1.local" "$(hostname -I | awk '{print $1}')"
