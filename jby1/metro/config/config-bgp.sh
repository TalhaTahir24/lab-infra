#!/bin/bash
set -e

INPUT="bgp_config.txt"

while read -r CONTAINER LOCAL_AS NEIGHBOR_IP REMOTE_AS; do
    [[ "$CONTAINER" =~ ^#.*$ || -z "$CONTAINER" ]] && continue

    echo "[*] Configuring BGP on $CONTAINER"

    docker exec -i "$CONTAINER" vtysh <<EOF
configure terminal
router bgp $LOCAL_AS
neighbor $NEIGHBOR_IP remote-as $REMOTE_AS
end
write memory
exit
EOF

    echo "[+] BGP configured on $CONTAINER: AS $LOCAL_AS, neighbor $NEIGHBOR_IP remote AS $REMOTE_AS"
done < "$INPUT"