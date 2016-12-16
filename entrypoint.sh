#!/bin/bash
if [ "$DEBUG" == "1" ]; then
    set -x
fi

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

iptables -t nat -A POSTROUTING -s ${OVPN_NETWORK} -o ${OVPN_NATDEVICE} -j MASQUERADE

# Used for assigning custom configurations (ie static IP addresses) to specific clients
if [ -d "$OPENVPN/ccd" ]; then
    addArg "--client-config-dir" "$OPENVPN/ccd"

    if [ -d ${OVPN_PORTMAPPING} ]; then
        for port in $(ls -1 ${OVPN_PORTMAPPING}); do
            destination=$(cat ${OVPN_PORTMAPPING}/${port})
            echo "Routing ${PODIPADDR}:${port} to ${destination}"
            iptables -t nat -A PREROUTING -p tcp -d $PODIPADDR --dport ${port} -j DNAT --to $destination
        done
    fi
fi

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# Use a hacky hardlink as the CRL Needs to be readable by the user/group
# OpenVPN is running as.  Only pass arguments to OpenVPN if it's found.
if [ -r "$EASYRSA_PKI/crl.pem" ]; then
    if [ ! -r "$OPENVPN/crl.pem" ]; then
        ln "$EASYRSA_PKI/crl.pem" "$OPENVPN/crl.pem"
        chmod 644 "$OPENVPN/crl.pem"
    fi
    addArg "--crl-verify" "$OPENVPN/crl.pem"
fi

if [ "$DEBUG" == "1" ]; then
  echo "openvpn.conf:"
  cat $OVPN_CONFIG
fi

echo "Running 'openvpn ${ARGS[@]} ${USER_ARGS[@]}'"
exec openvpn ${ARGS[@]} ${USER_ARGS[@]}
