#!/bin/bash
host=`hostname`
checkmkfqdn='REPLACE_FQDN'
checkmksite='REPLACE_SITE'
checkmkusername='REPLACE_USERNAME'
checkmkpassword='REPLACE_PASSWORD'
deleteurl="https://$checkmkfqdn/$checkmksite/check_mk/api/1.0/objects/host_config/$host"
posturl="https://$checkmkfqdn/$checkmksite/check_mk/api/1.0/domain-types/host_config/collections/all?bake_agent=false"
body_template='"folder": "/", "host_name": "%s"'
body_json_string=$(printf "$body_template" "$host")
auth_template='Authorization: Bearer %s %s'
auth_header=$(printf "$auth_template" $checkmkusername $checkmkpassword)

curl --fail -X 'DELETE' "$deleteurl" -H 'accept: */*' -H "$auth_header"
curl -X 'POST' "$posturl" \
 -H 'accept: application/json' -H "$auth_header" \
 -H 'Content-Type: application/json' -d "{ $body_json_string }"
cmk-agent-ctl register --hostname $host --server $checkmkfqdn --site $checkmksite --user $checkmkusername --password $checkmkpassword --trust-cert

rm /etc/salt/minion_id
hostname > /etc/salt/minion_id
systemctl enable salt-minion
systemctl start salt-minion
rm /usr/local/bin/postbuild_job.sh
