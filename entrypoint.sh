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

    cat /dev/null > $CONFIGFILE
    echo "$SLAPD_INCLUDES" >> $CONFIGFILE
    if [ -n "$SSL_KEY" ]; then
        echo "TLSCertificateKeyFile /etc/pki/tls/private/server.key" >> $CONFIGFILE
    fi
    if [ -n "$SSL_CERT" ]; then
        echo "TLSCertificateFile    /etc/pki/tls/certs/server.crt" >> $CONFIGFILE
    fi
    if [ -n "$SSL_CA_CERTS" ]; then
        echo "TLSCACertificateFile  /etc/pki/tls/certs/ca-bundle.crt" >> $CONFIGFILE
    fi
    echo "$SLAPD_CONF" >> $CONFIGFILE
    echo "$SLAPD_MODULES" >> $CONFIGFILE
    echo "$SLAPD_ACIS" >> $CONFIGFILE
    echo "$SLAPD_DATABASE" >> $CONFIGFILE

}


###########################################################
# MAIN
###########################################################


if [ -z "$SLAPD_CONF" ]; then
    echo "The SLAPD_CONF environment variable is not specified" 2>&1
    exit 2
fi

create_conf

mv /etc/openldap/slapd.d  /etc/openldap/slapd.d.disabled

install_sslkey

if [ -n "$LDIF_SEED_URL" ] && [ ! -e .skip-ldif ]; then
    touch .skip-ldif
    curl -s -o /tmp/seed.ldif "$LDIF_SEED_URL"
    if [ -n "$LDIF_SEED_SUFIX" ]; then
        echo "Running slapadd with $LDIF_SEED_URL: /usr/sbin/slapadd -b \"$LDIF_SEED_SUFIX\" -c -l /tmp/seed.ldif"
        /usr/sbin/slapadd -b "$LDIF_SEED_SUFIX" -c -v -l /tmp/seed.ldif
    else
        echo "Running slapadd with $LDIF_SEED_URL: /usr/sbin/slapadd -c -l /tmp/seed.ldif"
        /usr/sbin/slapadd -c -v -l /tmp/seed.ldif
    fi
fi

###########################################################
# Start LDAP server
###########################################################
echo "Start LDAP server"
exec /usr/sbin/slapd -h "${LDAPSERVERS:-ldap:/// ldaps:/// ldapi:///}" -u ldap -d "${SLAPD_DEBUG_LEVEL:-16640}"
