# Standard environment variables

* **OVPN_K8S_SERVICE_NETWORK** - The IP address space of the kubernetes service network in CIDR notation. **required** Default: none)
* **OVPN_K8S_POD_NETWORK** - The IP address space of the kubernetes pod overlay network in CIDR notation. **required** (Default: none)
* **OVPN_SERVER_URL** - The openvpn endpoint this pod is exposed as in `$proto://$fqdn:$port` notation. **required** (Default: none)
* OVPN_NETWORK - The openvpn client network. (Default: `10.140.0.0/24`)
* OVPN_PROTO - The openvpn protocol used. (Default: set from `OVPN_SERVER_URL`)
* OVPN_NATDEVICE - The outgoing device that routes to the kubernetes overlay network. (Default: `eth0`)
* OVPN_K8S_DOMAIN - The DNS search domain pushed to clients. (Default: `svc.cluster.local`)
* OVPN_K8S_DNS - The DNS resolver pushed to clients. (Default: resolver used in openvpn pod itself)
* OVPN_VERB - The verbosity of openvpn logs. (Default: `3`)
* OVPN_DEFROUTE - Whether to allow clients to route traffic other than pod/service networks. Set to `1` to allow, set to `2` to push a default route to clients. (Default: `0`)
* OVPN_ROUTES - Comma separated list of CIDR routes to push to clients and configure firewall rules for (Default: `$OVPN_K8S_SERVICE_NETWORK,$OVPN_K8S_POD_NETWORK`)
* DEBUG - Set this variable to any value to print each command executed and set `OVPN_DEBUG` to `5`.
