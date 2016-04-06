#!/bin/bash

# environment variables:
# SSL_CERT - ssl cert, a pem file with private key followed by public certificate, '\n'(two chars) as the line separator (optional)

#CONFDIR=.
CONFIGFILE=/etc/openldap/slapd.conf

#####################################################
function install_sslkey {
    if [ -n "$SSL_KEY" ]; then
        echo "$SSL_KEY" >  /etc/pki/tls/private/server.key
        unset SSL_KEY
    fi
    if [ -n "$SSL_CERT" ]; then
        echo "$SSL_CERT" > /etc/pki/tls/certs/server.crt
        unset SSL_CERT
    fi
    if [ -n "$SSL_CA_CERTS" ]; then
        echo "$SSL_CA_CERTS" > /etc/pki/tls/certs/ca-bundle.crt
        unset SSL_CA_CERTS
    fi
}


#####################################################
function create_conf {

    echo "$LDAP_CONF" >> $CONFIGFILE

}


###########################################################
# MAIN
###########################################################


if [ -z "$LDAP_CONF" ]; then
    echo "The LDAP_CONF environment variable is not specified" 2>&1
    exit 2
fi

cat /dev/null > $CONFIGFILE
if [ -n "$SSL_KEY" ]; then
    echo "TLSCertificateKeyFile /etc/pki/tls/private/server.key" >> $CONFIGFILE
fi
if [ -n "$SSL_CERT" ]; then
    echo "TLSCertificateFile    /etc/pki/tls/certs/server.crt" >> $CONFIGFILE
fi
if [ -n "$SSL_CA_CERTS" ]; then
    echo "TLSCACertificateFile  /etc/pki/tls/certs/ca-bundle.crt" >> $CONFIGFILE
fi

create_conf
install_sslkey

if [ -n "$LDIF_SEED_URL" ]; then
    curl -s -o /tmp/seed.ldif "$LDIF_SEED_URL" && /usr/sbin/slapadd -l /tmp/seed.ldif
fi
###########################################################
# Start LDAP server
###########################################################
exec /usr/sbin/slapd -h "${LDAPSERVERS:-ldap:/// ldaps:/// ldapi:///}" -u ldap -d "${SLAPD_DEBUG_LEVEL:-16640}"
