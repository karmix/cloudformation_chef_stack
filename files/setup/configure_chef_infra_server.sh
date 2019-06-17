# This does the following:
#  - Installs Chef Infra Server
#  - Creates an Admin User
#  - Uploads Admin key/password to an S3 bucket
#
# Requirements:
#  The following ENV vars must be set:
#    - CHEF_AUTOMATE_FQDN
#    - CHEF_AUTOMATE_API_TOKEN
#    - CHEF_INFRA_ADMIN_USERNAME
#    - CHEF_INFRA_ADMIN_PASSWORD
#    - CHEF_INFRA_ADMIN_FULLNAME
#    - CHEF_INFRA_ADMIN_EMAIL
#    - CHEF_INFRA_ORG_NAME
#    - CHEF_INFRA_FQDN
#    - CHEF_SECRETS_BUCKET
#    - CHEF_SUPERMARKET_FQDN
#  The following files must exist:
#    - /root/chef-admin.pub
#    - /root/validator.pub


# Install Chef Server
curl -L https://omnitruck.chef.io/install.sh | bash -s -- -P chef-server
chef-server-ctl reconfigure

# Create user and org from pre-generated keys
chef-server-ctl user-create \
                $CHEF_INFRA_ADMIN_USERNAME \
                $CHEF_INFRA_ADMIN_FULLNAME \
                $CHEF_INFRA_ADMIN_EMAIL \
                "$CHEF_INFRA_ADMIN_PASSWORD" \
                -f /dev/null # Key will be deleted and replaced

# Delete admin user default key
chef-server-ctl delete-user-key \
                $CHEF_INFRA_ADMIN_USERNAME \
                default

# Create new default key for admin user
chef-server-ctl add-user-key \
                $CHEF_INFRA_ADMIN_USERNAME \
                --key-name default \
                --public-key-path /root/chef-admin.pub # Must exist prior to running command

# Create Chef Org and remove default validator key
chef-server-ctl org-create \
                $CHEF_INFRA_ORG_NAME \
                $CHEF_INFRA_ORG_NAME \
                --association_user $CHEF_INFRA_ADMIN_USERNAME \
                -f /dev/null # Key will be deleted and replaced

# Delete default validator key
chef-server-ctl delete-client-key \
                $CHEF_INFRA_ORG_NAME \
                $CHEF_INFRA_ORG_NAME-validator \
                default

chef-server-ctl add-client-key \
                $CHEF_INFRA_ORG_NAME \
                $CHEF_INFRA_ORG_NAME-validator \
                --key-name default \
                --public-key-path /root/validator.pub # must exist prior to running command

# Add config to report to Automate
cat <<EOF | tee -a /etc/opscode/chef-server.rb
api_fqdn "$CHEF_INFRA_FQDN"
data_collector['root_url'] = 'https://$CHEF_AUTOMATE_FQDN/data-collector/v0/'
data_collector['proxy'] = true
profiles['root_url'] = 'https://$CHEF_AUTOMATE_FQDN'

# Allow larger reports from InSpec (e.g. CIS Windows)
opscode_erchef['max_request_size'] = '10000000'
nginx['client_max_body_size'] = '2500m'

# Supermarket Connections
oc_id['applications'] ||= {}
oc_id['applications']['supermarket'] = {
  'redirect_uri' => 'https://$CHEF_SUPERMARKET_FQDN/auth/chef_oauth2/callback'
}
EOF

# Configure Data Collection
chef-server-ctl set-secret data_collector token "$CHEF_AUTOMATE_API_TOKEN"
chef-server-ctl restart nginx
chef-server-ctl restart opscode-erchef

# Final reconfigure
chef-server-ctl reconfigure

# TODO: Build partial Supermarket JSON
JSON_UID="$(cat /etc/opscode/oc-id-applications/supermarket.json | grep uid | cut -d'"' -f 4)"
JSON_SECRET="$(cat /etc/opscode/oc-id-applications/supermarket.json | grep secret | cut -d'"' -f 4)"
cat <<EOF > /root/supermarket.json
  {
      "chef_server_url": "https://$CHEF_INFRA_FQDN",
      "chef_oauth2_app_id": "$JSON_UID",
      "chef_oauth2_secret": "$JSON_SECRET",
  }
EOF
