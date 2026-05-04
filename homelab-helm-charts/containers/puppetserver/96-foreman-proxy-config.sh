# Use environment variables for configuration
PUPPET_DOMAIN=${PUPPET_DOMAIN:-"puppet.svc.cluster.local"}
PUPPET_COMPILERS_DOMAIN=${PUPPET_COMPILERS_DOMAIN:-"puppetserver-puppet-compilers-headless.puppet.svc.cluster.local"}

if [ "$HOSTNAME" == "puppet" ]; then

cat > /etc/foreman-proxy/settings.d/puppetca_http_api.yml << EOF
---
# URL of the puppet master itself for API requests.
:puppet_url: https://puppetserver-puppet:8140
#
# SSL certificates used to access the CA API.
:puppet_ssl_ca: /etc/puppetlabs/puppet/ssl/certs/ca.pem
:puppet_ssl_cert: /etc/puppetlabs/puppet/ssl/certs/$(hostname).${PUPPET_DOMAIN}.pem
:puppet_ssl_key: /etc/puppetlabs/puppet/ssl/private_keys/$(hostname).${PUPPET_DOMAIN}.pem
EOF

cat > /etc/foreman-proxy/settings.d/puppetca.yml << EOF
---
# Can be true, false, or http/https to enable just one of the protocols
:enabled: true

# valid providers:
#   - puppetca_hostname_whitelisting (verify CSRs based on a hostname whitelist)
#   - puppetca_token_whitelisting (verify CSRs based on a token whitelist)
#:use_provider: puppetca_hostname_whitelisting
EOF


else

cat > /etc/foreman-proxy/settings.d/puppet.yml << EOF
---
# Can be true, false, or http/https to enable just one of the protocols
:enabled: true
EOF

cat > /etc/foreman-proxy/settings.d/puppet_proxy_puppet_api.yml << EOF
---
# URL of the puppet master itself for API requests.
:puppet_url: https://puppetserver-puppet-compilers:8140
#
# SSL certificates used to access the puppet API
:puppet_ssl_ca: /etc/puppetlabs/puppet/ssl/certs/ca.pem
:puppet_ssl_cert: /etc/puppetlabs/puppet/ssl/certs/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem
:puppet_ssl_key: /etc/puppetlabs/puppet/ssl/private_keys/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem
#
# Smart Proxy api timeout when Puppet's environment classes api is used and classes cache is disabled
#:api_timeout: 30
EOF
fi