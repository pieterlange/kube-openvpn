#!/bin/bash
[ $DEBUG ] && set -x

while true; do
    if [ -d $OVPN_CCD ]; then

        if [ -d $OVPN_PORTMAPPING ]; then
            inotifywait -e modify -e create -e delete $OVPN_PORTMAPPING

            # Flush any old rules.
            iptables -t nat -F
            for port in $(ls -1 ${OVPN_PORTMAPPING}); do
                dest_cname=$(cut -d':' -f1 ${OVPN_PORTMAPPING}/${port})
                dest_port=$(cut -d':' -f2 ${OVPN_PORTMAPPING}/${port})
                if [ -f ${OVPN_CCD}/${dest_cname} ]; then
                    dest_ip=$(grep 'ifconfig-push' $OVPN_CCD/${dest_cname} | cut -d' ' -f2)
                    echo "Routing ${PODIPADDR}:${port} to ${dest_ip}:${dest_port} (${dest_cname})"
                    iptables -t nat -A PREROUTING -p tcp -d $PODIPADDR --dport ${port} -j DNAT --to ${dest_ip}:${dest_port}
                else
                    echo "ERROR: client configuration for ${dest_cname} not found"
                fi
            done
        else
            # Watch $OPENVPN directory for portmapping directory creation
            inotifywait -e create -qq $OPENVPN

            # Give it time to settle
            sleep 60
        fi
    else
        # Watch $OPENVPN directory for client configuration directory creation
        inotifywait -e create -qq $OPENVPN

        # Give it time to settle
        sleep 60
    fi
done
