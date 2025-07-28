#!/bin/bash
set -e

echo "[*] Running core uplink configuration…"
/root/lab-infra/jby1/core/uplink/uplink.sh

echo "[*] Running core downlink configuration…"
/root/lab-infra/jby1/core/downlink/downlink.sh


for c in ksa_core uae_core pak_core usa_core; do
    echo "[*] Restoring iptables rules inside $c"
    docker exec "$c" sh -c 'iptables-restore < /etc/iptables/rules.v4'
done

echo "[+] Core network setup complete."