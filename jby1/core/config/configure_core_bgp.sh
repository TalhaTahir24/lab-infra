#!/bin/bash
set -e

INPUT="bgp_core_config.txt"

while read -r CONTAINER LOCAL_AS PEER_IP REMOTE_AS DEFAULT_ORIG; do
    [[ "$CONTAINER" =~ ^#.*$ || -z "$CONTAINER" ]] && continue
    DEFAULT_ORIG=$(echo "$DEFAULT_ORIG" | tr -d '\r')
    echo "[*] Configuring BGP on $CONTAINER: peer $PEER_IP AS $REMOTE_AS"

    CMD="
configure terminal
router bgp $LOCAL_AS
neighbor $PEER_IP remote-as $REMOTE_AS
"

    if [[ "$DEFAULT_ORIG" == "yes" ]]; then
        CMD+="
neighbor $PEER_IP default-originate
"
    fi

    CMD+="
end
write memory
exit
"

    docker exec -i "$CONTAINER" vtysh <<< "$CMD"

    echo "[+] Configured BGP on $CONTAINER with neighbor $PEER_IP (AS $REMOTE_AS)"
done < "$INPUT"