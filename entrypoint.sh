#!/bin/bash
[[ $DEBUG ]] && set -x && OVPN_VERB=${OVPN_VERB:-5}

set -ae

source /usr/local/bin/func.sh

addArg "--config" "$OVPN_CONFIG"

# Server name is in the form "udp://vpn.example.com:1194"
if [[ "$OVPN_SERVER_URL" =~ ^((udp|tcp)://)?([0-9a-zA-Z\.\-]+)(:([0-9]+))?$ ]]; then
    OVPN_PROTO=${BASH_REMATCH[2]};
    OVPN_CN=${BASH_REMATCH[3]};
    OVPN_PORT=${BASH_REMATCH[5]};
else
    echo "Need to pass in OVPN_SERVER_URL in 'proto://fqdn:port' format"
    exit 1
fi

OVPN_NETWORK="${OVPN_NETWORK:-10.140.0.0/24}"
OVPN_PROTO="${OVPN_PROTO:-tcp}"
OVPN_NATDEVICE="${OVPN_NATDEVICE:-eth0}"
OVPN_K8S_DOMAIN="${OVPN_K8S_DOMAIN:-svc.cluster.local}"
OVPN_VERB=${OVPN_VERB:-3}

if [ ! -d "${EASYRSA_PKI}" ]; then
    echo "PKI directory missing. Did you mount in your Secret?"
    exit 1
fi

if [ -z "${OVPN_K8S_SERVICE_NETWORK}" ]; then
    echo "Service network not specified"
    exit 1
fi

if [ -z "${OVPN_K8S_POD_NETWORK}" ]; then
    echo "Pod network not specified"
    exit 1
fi

# You don't need to set this variable unless you touched your dnsPolicy for this pod.
if [ -z "${OVPN_K8S_DNS}" ]; then
    OVPN_K8S_DNS=$(cat /etc/resolv.conf | grep -i nameserver | head -n1 | cut -d ' ' -f2)
fi

# Do some CIDR conversion
OVPN_NETWORK_ROUTE=$(getroute ${OVPN_NETWORK})
OVPN_K8S_SERVICE_NETWORK_ROUTE=$(getroute $OVPN_K8S_SERVICE_NETWORK)
OVPN_K8S_POD_NETWORK_ROUTE=$(getroute $OVPN_K8S_POD_NETWORK)

envsubst < $OVPN_TEMPLATE > $OVPN_CONFIG

IFS=',' read -r -a routes <<< "$OVPN_ROUTES"
routes+=("$OVPN_K8S_SERVICE_NETWORK" "$OVPN_K8S_POD_NETWORK")

for route in "${routes[@]}"; do
    if [[ "$route" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$ ]]; then
        network_route=$(getroute $route)
        addArg "--push" "route ${network_route}"
    else
        echo "$(date "+%a %b %d %H:%M:%S %Y") Dropping invalid route '${route}'."
        routes=("${routes[@]/$route}" )
    fi
done

if [ $OVPN_DEFROUTE -gt 0 ]; then
    iptables -t nat -A POSTROUTING -s ${OVPN_NETWORK} -o ${OVPN_NATDEVICE} -j MASQUERADE
    [ $OVPN_DEFROUTE -gt 1 ] && addArg "--push" "redirect-gateway def1"
else
    for route in "${routes[@]}"; do
        iptables -t nat -A POSTROUTING -s ${OVPN_NETWORK} -d $route -o ${OVPN_NATDEVICE} -j MASQUERADE
    done
fi

# Use client configuration directory if it exists.
if [ -d "$OVPN_CCD" ]; then
    addArg "--client-config-dir" "$OVPN_CCD"

    # Watch for changes to port translation configmap in the background
    /sbin/watch-portmapping.sh &
fi

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# Load CRL if it is readable (remember to set defaultMode: 555 (ugo+rx) on the volume)
if [ -r $OVPN_CRL ]; then
    addArg "--crl-verify" "$OVPN_CRL"
fi

# Optional OTP authentication support
if [ -d "${OVPN_OTP_AUTH:-}" ]; then
    addArg "--plugin" "/usr/lib/openvpn/plugins/openvpn-plugin-auth-pam.so" "openvpn"
    addArg "--reneg-sec" "0"
fi

if [ $DEBUG ]; then
    echo "openvpn.conf:"
    cat $OVPN_CONFIG
fi

echo "$(date "+%a %b %d %H:%M:%S %Y") Running 'openvpn ${ARGS[@]} ${USER_ARGS[@]}'"
exec openvpn ${ARGS[@]} ${USER_ARGS[@]}
