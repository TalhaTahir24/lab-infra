#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT="$SCRIPT_DIR/downlink.txt"

generate_mac() {
    printf '02:50:%02x:%02x:%02x:%02x\n' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

while read -r CONTAINER VETH_HOST VETH_CONT BRIDGE IP; do
    echo "[*] Configuring downlink for $CONTAINER ($VETH_CONT)"

    PID=$(docker inspect -f '{{.State.Pid}}' "$CONTAINER" 2>/dev/null) || {
        echo "[-] Container $CONTAINER not found or not running"
        continue
    }

    # Clean up old
    ip link del "$VETH_HOST" 2>/dev/null || true

    # Create veth pair
    ip link add "$VETH_HOST" type veth peer name "${VETH_HOST}-c"
    ip link set "$VETH_HOST" up
    ip link set "$VETH_HOST" master "$BRIDGE"

    # Move container end into container namespace and rename
    ip link set "${VETH_HOST}-c" netns "$PID"
    nsenter -t "$PID" -n ip link set "${VETH_HOST}-c" name "$VETH_CONT"
    nsenter -t "$PID" -n ip link set "$VETH_CONT" address "$(generate_mac)"
    nsenter -t "$PID" -n ip link set "$VETH_CONT" up
    nsenter -t "$PID" -n ip addr add "$IP" dev "$VETH_CONT"

    echo "[+] Downlink $VETH_CONT in $CONTAINER → $IP"