#!/bin/bash
set -euo pipefail

BASE_DIR="./docker"
SITES=(
    "jed" "dmm" "ruh"
    "auh" "shj" "fjr"
    "lhr" "khi" "isb"
    "ny"  "dc"  "ca"
)
echo "[+] Creating FRR config folders and files…"

for site in "${SITES[@]}"; do
    DIR="$BASE_DIR/${site}_frr"
    echo "  - Setting up $DIR"
    mkdir -p "$DIR"

    # Create empty frr.conf
    > "$DIR/frr.conf"

    # Create vtysh.conf
    echo "service integrated-vtysh-config" > "$DIR/vtysh.conf"

    # Create daemons file with specific services enabled
    cat > "$DIR/daemons" <<EOF
zebra=yes
bgpd=yes
ospfd=yes
ldpd=yes
mgmtd=yes
nhrpd=yes
EOF

done

echo "[+] Done. Folders and files created in $BASE_DIR/"