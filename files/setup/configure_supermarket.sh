# Requirements:
#  The following files must exist:
#    - /root/supermarket.json (OCID info from Chef Server)
#  The following ENV vars are required:
#    - CHEF_SUPERMARKET_FQDN
#    - CHEF_SUPERMARKET_OAUTH_SSL_VERIFICATION
#  The following ENV vars are optional:
#    - CHEF_SUPERMARKET_SSL_CERT
#    - CHEF_SUPERMARKET_SSL_KEY


curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P supermarket

#supermarket-ctl reconfigure

mkdir -p /etc/supermarket
cp /root/supermarket.json /etc/supermarket/supermarket.json

echo "default['supermarket']['fqdn'] = '$CHEF_SUPERMARKET_FQDN'" >> /etc/supermarket/supermarket.rb
echo "default['supermarket']['chef_oauth2_verify_ssl'] = $CHEF_SUPERMARKET_OAUTH_SSL_VERIFICATION" >> /etc/supermarket/supermarket.rb

if [ -n "$CHEF_SUPERMARKET_SSL_CERT" ] && [ -n "$CHEF_SUPERMARKET_SSL_CERT" ]; then
  mkdir -p /var/opt/supermarket/ssl/ca/
  echo "$CHEF_SUPERMARKET_SSL_CERT" > "/var/opt/supermarket/ssl/ca/$CHEF_SUPERMARKET_FQDN.crt"
  echo "$CHEF_SUPERMARKET_SSL_KEY" > "/var/opt/supermarket/ssl/ca/$CHEF_SUPERMARKET_FQDN.key"
  echo "default['supermarket']['nginx']['force_ssl'] = true" >> /etc/supermarket/supermarket.rb
  echo "default['supermarket']['ssl']['certificate'] = '/var/opt/supermarket/ssl/ca/$CHEF_SUPERMARKET_FQDN.crt'" >> /etc/supermarket/supermarket.rb
  echo "default['supermarket']['ssl']['certificate_key'] = '/var/opt/supermarket/ssl/ca/$CHEF_SUPERMARKET_FQDN.key'" >> /etc/supermarket/supermarket.rb
fi

supermarket-ctl reconfigure
