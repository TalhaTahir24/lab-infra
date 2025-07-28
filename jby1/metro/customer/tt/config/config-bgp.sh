#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT="$SCRIPT_DIR/bgp_networks.txt"

if [[ ! -f "$INPUT" ]]; then
    echo "Input file '$INPUT' not found!"
    exit 1
fi

while read -r CONTAINER ASN SUBNET; do
    [[ -z "$CONTAINER" || "$CONTAINER" =~ ^# ]] && continue

    echo "[*] Configuring BGP on $CONTAINER (ASN $ASN) to advertise $SUBNET"

    docker exec -i "$CONTAINER" vtysh <<EOF
conf t
router bgp $ASN
network $SUBNET
do wr
exit
EOF

    echo "[+] Configured $CONTAINER to advertise $SUBNET under ASN $ASN"
done < "$INPUT"

echo "✅ All BGP advertisements configured."