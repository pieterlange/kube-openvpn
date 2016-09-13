# Smallest base image
FROM alpine:3.4

MAINTAINER Pieter Lange <pieter@ptlc.nl>

RUN echo "http://dl-4.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories && \
    echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    apk add --update openvpn iptables bash easy-rsa && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

# Needed by scripts
ENV OPENVPN /etc/openvpn
ENV OVPN_CONFIG $OPENVPN/openvpn.conf
ENV EASYRSA /usr/share/easy-rsa
ENV EASYRSA_PKI $OPENVPN/pki

# Some PKI scripts.
ADD ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*

# entry point takes care of setting conf values
COPY entrypoint.sh /sbin/entrypoint.sh
COPY openvpn.conf $OVPN_CONFIG

CMD ["/sbin/entrypoint.sh"]
