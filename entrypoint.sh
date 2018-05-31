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


######################################################
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

# workaround for /var/lib/ldap on external volume:
# make sure we have the version from the docker image
# instead of one that may have been modified locally
if [ -f /var/lib/ldap/DB_CONFIG ]; then
	rm -f /var/lib/ldap/DB_CONFIG
fi
cp /etc/openldap.local/DB_CONFIG /var/lib/ldap/

# workaround for /etc/openldap on external volume
# make sure we have the version from the docker image
# instead of one that may have been modified locally

if [ -f /etc/openldap/schema/eionet.schema ]; then
	rm -f /etc/openldap/schema/eionet.schema
fi
cp /etc/openldap.local/eionet.schema /etc/openldap/schema/

mv /etc/openldap/slapd.d  /etc/openldap/slapd.d.disabled

install_sslkey

if [ -n "$LDIF_SEED_URL" ] && [ ! -e /var/lib/ldap/.skip-ldif-import ]; then
    # creating the ldif import trigger file in the persistent volume instead of under /
    touch /var/lib/ldap/.skip-ldif-import
    curl -s -o /tmp/seed.ldif "$LDIF_SEED_URL"
    if [ -n "$LDIF_SEED_SUFFIX" ]; then
        echo "Running slapadd with $LDIF_SEED_URL: /usr/sbin/slapadd -b \"$LDIF_SEED_SUFFIX\" -c -l /tmp/seed.ldif"
        /usr/sbin/slapadd -b "$LDIF_SEED_SUFFIX" -c -v -l /tmp/seed.ldif
    else
        echo "Running slapadd with $LDIF_SEED_URL: /usr/sbin/slapadd -c -l /tmp/seed.ldif"
        /usr/sbin/slapadd -c -v -l /tmp/seed.ldif
    fi
    # slapadd creates files owned by root; slapd will not start unless we change that
    if [ -n "$LDAP_UID" ] && [ -n "$LDAP_GID" ]; then
	/usr/bin/chown $LDAP_UID:$LDAP_GID -R /var/lib/ldap
    fi
fi

###########################################################
# Start LDAP server
###########################################################
echo "Start LDAP server"
exec /usr/sbin/slapd -h "${LDAPSERVERS:-ldap:/// ldaps:/// ldapi:///}" -u ldap -d "${SLAPD_DEBUG_LEVEL:-16640}"
