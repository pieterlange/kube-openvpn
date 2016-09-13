#!/bin/bash

# Build runtime arguments array based on environment
USER_ARGS=("${@}")
ARGS=()

# Checks if ARGS already contains the given value
function hasArg {
    local element
    for element in "${@:2}"; do
        [ "${element}" == "${1}" ] && return 0
    done
    return 1
}

# Adds the given argument if it's not already specified.
function addArg {
    local arg="${1}"
    [ $# -ge 1 ] && local val="${2}"
    if ! hasArg "${arg}" "${USER_ARGS[@]}"; then
        ARGS+=("${arg}")
        [ $# -ge 1 ] && ARGS+=("${val}")
    fi
}

# Convert 1.2.3.4/24 -> 255.255.255.0
cidr2mask()
{
    local i
    local subnetmask=""
    local cidr=${1#*/}
    local full_octets=$(($cidr/8))
    local partial_octet=$(($cidr%8))

    for ((i=0;i<4;i+=1)); do
        if [ $i -lt $full_octets ]; then
            subnetmask+=255
        elif [ $i -eq $full_octets ]; then
            subnetmask+=$((256 - 2**(8-$partial_octet)))
        else
            subnetmask+=0
        fi
        [ $i -lt 3 ] && subnetmask+=.
    done
    echo $subnetmask
}

# Used often enough to justify a function
getroute() {
    echo ${1%/*} $(cidr2mask $1)
}

# Server name is in the form "udp://vpn.example.com:1194"
if [[ "$OVPN_SERVER_URL" =~ ^((udp|tcp)://)?([0-9a-zA-Z\.\-]+)(:([0-9]+))?$ ]]; then
    OVPN_PROTO=${BASH_REMATCH[2]};
    OVPN_CN=${BASH_REMATCH[3]};
    OVPN_PORT=${BASH_REMATCH[5]};
else
    echo "Need to pass in OVPN_SERVER_URL in 'proto://fqdn:port' format"
    exit 1
fi
