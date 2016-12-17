#!/bin/bash
[ $DEBUG ] && set -x

iptables -t nat -N KUBEOPENVPNPORTFORWARD
iptables -t nat -A PREROUTING -j KUBEOPENVPNPORTFORWARD

while true; do
    if [ -d $OVPN_CCD ]; then

        if [ -d $OVPN_PORTMAPPING ]; then
            # Flush any old NAT rules.
            iptables -t nat -F KUBEOPENVPNPORTFORWARD

            for port in $(ls -1 ${OVPN_PORTMAPPING}); do
                dest_cname=$(cut -d':' -f1 ${OVPN_PORTMAPPING}/${port})
                dest_port=$(cut -d':' -f2 ${OVPN_PORTMAPPING}/${port})
                if [ -f ${OVPN_CCD}/${dest_cname} ]; then
                    dest_ip=$(grep 'ifconfig-push' $OVPN_CCD/${dest_cname} | cut -d' ' -f2)
                    echo "Routing ${PODIPADDR}:${port} to ${dest_ip}:${dest_port} (${dest_cname})"
                    iptables -t nat -A KUBEOPENVPNPORTFORWARD -p tcp -d $PODIPADDR --dport ${port} -j DNAT --to ${dest_ip}:${dest_port}
                else
                    echo "ERROR: client configuration for ${dest_cname} not found"
                fi
            done

            # Done. Block for updates to configmap.
            inotifywait -qq -e modify -e create -e delete $OVPN_PORTMAPPING
        else
            # Watch $OPENVPN directory for portmapping directory creation
            inotifywait -qq -e create $OPENVPN

            # Give it time to settle
            sleep 60
        fi
    else
        # Watch $OPENVPN directory for client configuration directory creation
        inotifywait -qq -e create $OPENVPN

        # Give it time to settle
        sleep 60
    fi
done
