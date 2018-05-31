FROM centos:7
MAINTAINER Søren Roug <soren.roug@eea.europa.eu>

# Can be mapped for a primary server
#VOLUME /var/lib/ldap

RUN yum install -y openldap-servers openldap openldap-clients wget \
    && mkdir -p /var/lib/ldap \
    && chown ldap.ldap /var/lib/ldap \
    && chmod 700 /var/lib/ldap

COPY entrypoint.sh /
RUN mkdir /etc/openldap.local
COPY eionet.schema /etc/openldap.local/
COPY DB_CONFIG /etc/openldap.local/

EXPOSE 636

CMD /entrypoint.sh
