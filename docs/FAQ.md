# Frequently asked questions

### "I don't like easyrsa"
Many people don't! This is fine, you can use your own PKI management system like [xca](http://xca.sourceforge.net). All you need to do is map the correct files into the `openvpn-pki` secret object and mount it into `/etc/openvpn/pki`. Refer to `deploy.sh` for details.

### I can't ping my kubernetes service
Kubernetes services aren't pingable, try connecting to the service port.

### I can't lookup my kubernetes service
  - Check if `kube-dns` is configured correctly
  - Check if you received the correct resolver (see `/etc/resolv.conf` on your client)
  - Make sure you can resolve the service by it's full cluster FQDN (eg `kubernetes.default.svc.cluster.local`)

### I can't lookup my kubernetes service (OSX)
See https://github.com/michthom/AlwaysAppendSearchDomains

Execute the following steps:
  * `sudo launchctl unload /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist`
  * `sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist AlwaysAppendSearchDomains -bool YES`
  * `sudo launchctl load /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist`

### The pod keeps crashing!
This shouldn't happen! Please set the `$DEBUG` environment variable (any value) and file an issue with a full logfile.

### Weird reachability issues
Make sure you're not already using `10.140.0.0/24` in your architecture. If you are, set the `$OVPN_NETWORK` environment variable to something non-conflicting

### I want to route all traffic through the VPN
Set `$OVPN_DEFROUTE` to a value of `1` on the kubernetes pod to enable VPN clients to route to other networks than the kubernetes pod/service networks. Set `$OVPN_DEFROUTE` to `2` to also push this configuration to the openvpn clients.

### Revoking clients
This works just like any other PKI system. If you followed the setup instructions, you're using easyrsa and client revocation is done as follows.

Revoke the client (where <CN> is the client name):
```
docker run --user=$(id -u) -e OVPN_SERVER_URL=tcp://vpn.my.fqdn:1194 -v $PWD:/etc/openvpn -ti ptlange/openvpn easyrsa revoke <CN>
```

Now update the CRL on the cluster:
```
./kube/update-crl.sh <namespace> [#days the CRL is valid]
```
