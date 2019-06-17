# Requirements:
#   The following ENV vars must be set:
#     - CHEF_AUTOMATE_FQDN
#     - CHEF_AUTOMATE_LICENSE # Optional if you want a trial license
#     - CHEF_AUTOMATE_ADMIN_USERNAME
#     - CHEF_AUTOMATE_ADMIN_PASSWORD
#     - CHEF_AUTOMATE_SSL_CERT
#     - CHEF_AUTOMATE_SSL_KEY

# TODO: Make me work on other OSs
yum install jq -y

# Render config.toml
cat <<EOF > /root/config.toml
[global.v1]
  fqdn = "$CHEF_AUTOMATE_FQDN"
  [[global.v1.frontend_tls]]
    # The TLS certificate for the load balancer frontend.
    cert = """${CHEF_AUTOMATE_SSL_CERT}"""

    # The TLS RSA key for the load balancer frontend.
    key = """${CHEF_AUTOMATE_SSL_KEY}"""
[deployment.v1]
  [deployment.v1.svc]
    channel = "current"
    upgrade_strategy = "at-once"
    deployment_type = "local"
[license_control.v1]
  [license_control.v1.svc]
    license = "${CHEF_AUTOMATE_LICENSE}"
[elasticsearch.v1.sys.runtime]
heapsize = "1g"
EOF

# Kernel tunings
echo 'vm.max_map_count=262144' | tee -a /etc/sysctl.d/automate.conf
echo 'vm.dirty_expire_centisecs=20000' | tee -a /etc/sysctl.d/automate.conf
sysctl -w vm.max_map_count=262144
sysctl -w vm.dirty_expire_centisecs=20000

# Install and deploy Chef Automate
curl https://packages.chef.io/files/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip | gunzip - > chef-automate
chmod +x chef-automate
mv chef-automate /usr/local/bin
chef-automate deploy /root/config.toml --accept-terms-and-mlsa --skip-preflight

# Create Admin Token
export TOK="$(chef-automate admin-token)"
echo $TOK  > /root/automate_admin_api_token.txt # For uploading to secrets bucket

# Create new admin (with password) and add it to the admins team
curl -k -H "api-token: $TOK" -H "Content-Type: application/json" -d "{\"name\":\"Chef Admin\", \"username\":\"$CHEF_AUTOMATE_ADMIN_USERNAME\", \"password\":\"$CHEF_AUTOMATE_ADMIN_PASSWORD\"}" https://localhost/api/v0/auth/users | jq -r .id
export USER_ID=`curl -k -H "api-token: $TOK" https://localhost/api/v0/auth/users/$CHEF_AUTOMATE_ADMIN_USERNAME | jq -r .id`
export TEAM_ID=`curl -k -H "api-token: $TOK" https://localhost/api/v0/auth/teams | jq -r '.teams[] | select(.name =="admins").id'`
curl -k -H "api-token: $TOK" -H "Content-Type: application/json" -d "{\"user_ids\":[\"$USER_ID\"]}" https://localhost/api/v0/auth/teams/$TEAM_ID/users
