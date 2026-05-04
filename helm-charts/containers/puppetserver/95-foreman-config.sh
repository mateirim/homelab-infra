# Use environment variables for configuration
FOREMAN_URL=${FOREMAN_URL:-"http://foreman.foreman.svc.cluster.local:3000"}
# Extract hostname from URL (strip protocol, port, and path)
FOREMAN_HOST=$(echo "${FOREMAN_URL}" | sed -e 's|^[^/]*//||' -e 's|/.*$||' -e 's|:.*$||')
# Derive domain from hostname (everything after the first dot)
FOREMAN_DOMAIN=${FOREMAN_HOST#*.}

PUPPET_DOMAIN=${PUPPET_DOMAIN:-"puppet.svc.cluster.local"}
PUPPET_COMPILERS_URL=${PUPPET_COMPILERS_URL:-"https://puppet-compilers.puppet.svc.cluster.local:8140"}
PUPPET_COMPILERS_DOMAIN=${PUPPET_COMPILERS_DOMAIN:-"puppetserver-puppet-compilers-headless.puppet.svc.cluster.local"}

curl -o /etc/puppetlabs/puppet/node.rb https://raw.githubusercontent.com/theforeman/puppet-puppetserver_foreman/master/files/enc.rb 
curl -o /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/reports/foreman.rb  https://raw.githubusercontent.com/theforeman/puppet-puppetserver_foreman/master/files/report.rb 
sed -i 's/reports = puppetdb/reports = puppetdb,foreman\nexternal_nodes = \/etc\/puppetlabs\/puppet\/node.rb\nnode_terminus  = exec/' /etc/puppetlabs/puppet/puppet.conf

if [ "$HOSTNAME" == "puppet" ]; then

cat > /etc/puppetlabs/puppet/foreman.yaml << EOF

# Update for your Foreman and Puppet server hostname(s)
:url: "${FOREMAN_URL}"
:ssl_ca: "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
:ssl_cert: "/etc/puppetlabs/puppet/ssl/certs/$(hostname).${PUPPET_DOMAIN}.pem"
:ssl_key: "/etc/puppetlabs/puppet/ssl/private_keys/$(hostname).${PUPPET_DOMAIN}.pem"
:fact_extension: "json"
# Advanced settings
:puppetdir: "/opt/puppetlabs/server/data/puppetserver"
:puppetuser: "puppet"
:facts: true
:timeout: 10
:threads: null
EOF

cat > /etc/foreman-proxy/settings.yml << EOF
:http_port: 9090
:https_port: 8443
:ssl_certificate: "/etc/puppetlabs/puppet/ssl/certs/$(hostname).${PUPPET_DOMAIN}.pem"
:ssl_ca_file: "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
:ssl_private_key: "/etc/puppetlabs/puppet/ssl/private_keys/$(hostname).${PUPPET_DOMAIN}.pem"
:trusted_hosts:
  - .${FOREMAN_HOST}
  - .${FOREMAN_DOMAIN}
  - ${FOREMAN_HOST}
:foreman_url: ${FOREMAN_URL}
:log_level: DEBUG
EOF

cp /etc/foreman.d/puppetca.yml /etc/foreman-proxy/settings.d
cp /etc/foreman.d/puppetca_http_api.yml /etc/foreman-proxy/settings.d
/usr/share/foreman-proxy/bin/smart-proxy &

else

cat > /etc/puppetlabs/puppet/foreman.yaml << EOF

# Update for your Foreman and Puppet server hostname(s)
:url: "${FOREMAN_URL}"
:ssl_ca: "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
:ssl_cert: "/etc/puppetlabs/puppet/ssl/certs/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem"
:ssl_key: "/etc/puppetlabs/puppet/ssl/private_keys/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem"
:fact_extension: "json"
# Advanced settings
:puppetdir: "/opt/puppetlabs/server/data/puppetserver"
:puppetuser: "puppet"
:facts: true
:timeout: 10
:threads: null
EOF

cat > /etc/foreman-proxy/settings.yml << EOF
:http_port: 9090
:https_port: 8443
:ssl_certificate: "/etc/puppetlabs/puppet/ssl/certs/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem"
:ssl_ca_file: "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
:ssl_private_key: "/etc/puppetlabs/puppet/ssl/private_keys/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem"
:foreman_url: ${FOREMAN_URL}
:log_level: DEBUG
:trusted_hosts:
  - .${FOREMAN_HOST}
  - .${FOREMAN_DOMAIN}
  - ${FOREMAN_HOST}

EOF

cat > /etc/foreman-proxy/settings.d/puppet_proxy_puppet_api.yml << EOF
---
# URL of the puppet master itself for API requests.
:puppet_url: ${PUPPET_COMPILERS_URL}
#
# SSL certificates used to access the puppet API
:puppet_ssl_ca: /etc/puppetlabs/puppet/ssl/certs/ca.pem
:puppet_ssl_cert: /etc/puppetlabs/puppet/ssl/certs/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem
:puppet_ssl_key: /etc/puppetlabs/puppet/ssl/private_keys/$(hostname).${PUPPET_COMPILERS_DOMAIN}.pem
#
# Smart Proxy api timeout when Puppet's environment classes api is used and classes cache is disabled
#:api_timeout: 30
EOF

cp /etc/foreman.d/puppet.yml /etc/foreman-proxy/settings.d
/usr/share/foreman-proxy/bin/smart-proxy &

fi
chmod +x /etc/puppetlabs/puppet/node.rb
