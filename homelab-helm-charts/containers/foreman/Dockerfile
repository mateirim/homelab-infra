FROM quay.io/centos/centos:stream9

ARG foreman_version="3.17"

LABEL foreman_version=${foreman_version}

# EL9 repositories
RUN dnf -y install https://yum.puppet.com/puppet8-release-el-9.noarch.rpm \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    https://yum.theforeman.org/releases/${foreman_version}/el9/x86_64/foreman-release.rpm

RUN dnf -y install foreman-release sudo 
RUN dnf install -y foreman foreman-service foreman-libvirt foreman-cli \
    foreman-console foreman-postgresql foreman-proxy \
    rubygem-foreman_templates rubygem-foreman_dhcp_browser \
    rubygem-puppetdb_foreman rubygem-foreman_puppet

COPY entrypoint.sh /entrypoint.sh
COPY --chown=foreman:foreman config/* /etc/foreman/

RUN chmod 755 /entrypoint.sh \
    && chown foreman:foreman /etc/foreman /usr/share/foreman/config/initializers/local_secret_token.rb \
    && chmod 600 /etc/foreman/encryption_key.rb /etc/foreman/database.yml \
    && echo "foreman ALL=NOPASSWD:/bin/update-ca-trust,/bin/dnf" >> /etc/sudoers 

RUN sed -i "s/config.public_file_server.enabled = ENV.fetch('RAILS_SERVE_STATIC_FILES', false) == 'true'/config.public_file_server.enabled = true/g" /usr/share/foreman/config/environments/production.rb
RUN sed -i "s/config.force_ssl = false/config.force_ssl = true/g" /usr/share/foreman/config/environments/production.rb

USER foreman
WORKDIR /usr/share/foreman

ENTRYPOINT ["/entrypoint.sh"]