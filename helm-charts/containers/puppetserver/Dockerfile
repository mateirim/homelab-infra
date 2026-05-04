FROM ghcr.io/voxpupuli/container-puppetserver:latest
# Fix expired Puppet GPG key by temporarily disabling the repo to install tools
RUN mv /etc/apt/sources.list.d/puppet8-release.list /etc/apt/sources.list.d/puppet8-release.list.bak \
    && apt update -y && apt install wget gnupg -y
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 4528B6CD9E61EF26 \
    && gpg --export 4528B6CD9E61EF26 > /etc/apt/trusted.gpg.d/puppet.gpg \
    && mv /etc/apt/sources.list.d/puppet8-release.list.bak /etc/apt/sources.list.d/puppet8-release.list
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 5B7C3E5A735BCB4D615829DC0BDDA991FD7AAC8A \
    && gpg --export 5B7C3E5A735BCB4D615829DC0BDDA991FD7AAC8A > /etc/apt/trusted.gpg.d/foreman.gpg
RUN echo "deb http://deb.theforeman.org/ jammy 3.17" | tee /etc/apt/sources.list.d/foreman.list
RUN echo "deb http://deb.theforeman.org/ plugins 3.17" | tee -a /etc/apt/sources.list.d/foreman.list
RUN apt-get update -y -y && apt install foreman-proxy -y
RUN apt install dnsutils -y
RUN chown -R 999:999 /etc/puppetlabs
RUN chown -R 999:999 /etc/foreman-proxy
ADD 95-foreman-config.sh /docker-entrypoint.d
ADD 96-foreman-proxy-config.sh /docker-entrypoint.d
RUN chmod +rx /docker-entrypoint.d/95-foreman-config.sh
RUN chmod +rx /docker-entrypoint.d/96-foreman-proxy-config.sh