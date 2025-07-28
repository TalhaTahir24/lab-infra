#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Please run as root"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT="$SCRIPT_DIR/uplink.txt"

generate_mac() {
    # Locally administered, unicast MAC starting with 02:60
    printf '02:60:%02x:%02x:%02x:%02x\n' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

while read -r CONTAINER VETH_HOST VETH_CONT BRIDGE IP GATEWAY; do
    echo "[*] Configuring uplink for $CONTAINER"
    PID=$(docker inspect -f '{{.State.Pid}}' "$CONTAINER" 2>/dev/null) || {
        echo "[-] Container $CONTAINER not found or not running"
        continue
    }

    ip link del "$VETH_HOST" 2>/dev/null || true
    ip link add "$VETH_HOST" type veth peer name "${VETH_HOST}-c"
    ip link set "$VETH_HOST" up
    ip link set "$VETH_HOST" master "$BRIDGE"
    ip link set "${VETH_HOST}-c" netns "$PID"

    MAC=$(generate_mac)

    nsenter -t "$PID" -n ip link set "${VETH_HOST}-c" name "$VETH_CONT"
    nsenter -t "$PID" -n ip link set "$VETH_CONT" address "$MAC"
    nsenter -t "$PID" -n ip link set "$VETH_CONT" up
    nsenter -t "$PID" -n ip addr add "$IP" dev "$VETH_CONT"
    nsenter -t "$PID" -n ip route add default via "$GATEWAY" || true

    echo "[+] Uplink for $CONTAINER on $VETH_CONT → $IP [$MAC]"
done < "$INPUT"