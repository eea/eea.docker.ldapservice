LDAP service
============

This is a Dockerfile for an ldap service where the full slapd.conf is stored in an environment variable called `LDAP_CONF`.
Optional environment variables: `SSL_KEY`, `SSL_CERT`, `SSL_CA_CERTS`, `LDIF_SEED_URL` and `LDIF_SEED_SUFFIX`.

The optional `LDIF_SEED_URL` is a URL to a file containing LDIF entries created by slapcat. It can be any URL known to `curl` - including `file:`.
The file will be loaded before the LDAP daemon is started.

The optional `LDIF_SEED_SUFFIX` is useful in the case of having multiple backend databases in the slapd.conf file. It will be used to determine which database to add entries to.

Example
-------

```
# Only for the primary copy of the database.
masterdata:
  image: busybox
  command: chown -R 55:55 /var/lib/ldap
  volumes:
  - "/var/lib/ldap"

ldapmaster:
  image: eeacms/ldapservice
  ports:
  - "2389:389"
  - "2636:636"
  volumes_from:
  - masterdata
  environment:
    LDIF_SEED_URL: file:/data/fulldump.ldif
    LDAP_CONF: |
        include /etc/openldap/schema/core.schema
        include /etc/openldap/schema/cosine.schema
        include /etc/openldap/schema/inetorgperson.schema
        include /etc/openldap/schema/nis.schema
        allow bind_v2
        sizelimit       10000
        timelimit       3600
        idletimeout     600
        pidfile /var/run/openldap/slapd.pid
        argsfile /var/run/openldap/slapd.args

        database bdb
        cachesize 50000
        idlcachesize 150000
        #loglevel 16640

#
# LDAP6 is a slave
#
ldap6:
  image: eeacms/ldapservice
  ports:
  - "389:389"
  - "636:636"
  links:
  - ldapmaster:ldapmaster
  environment:
    LDAP_CONF: |
        include /etc/openldap/schema/core.schema
        include /etc/openldap/schema/cosine.schema
        include /etc/openldap/schema/inetorgperson.schema
        include /etc/openldap/schema/eionet.schema
        include /etc/openldap/schema/nis.schema
        allow bind_v2
        sizelimit       10000
        timelimit       3600
        idletimeout 600
        pidfile  /var/run/openldap/slapd.pid
        argsfile /var/run/openldap/slapd.args
        syncrepl    rid=1
            provider=ldap://ldapmaster
            type=refreshOnly
            interval=00:00:05:00
        ...
    SSL_KEY: |
        -----BEGIN RSA PRIVATE KEY-----
        ...
    SSL_CERT: |
        -----BEGIN CERTIFICATE-----
        ...
    SSL_CA_CERTS: |
        -----BEGIN CERTIFICATE-----
        -----END CERTIFICATE-----
```

Build instructions
------------------

Built automatically at https://hub.docker.com/r/eeacms/ldapservice/ when a change is
pushed to GitHub. To ensure that you always have an immutable build for produuction
you create a new tag in GitHub.

    $ version=v1.3
    $ git tag -a $version -m "Release $version of the ldapservice"
    $ git push origin $version

