#!/bin/bash
set -euxo pipefail

exec > /var/log/user-data.log 2>&1

sudo labauto ansible

rm -rf /opt/roboshop-ansible
git clone "${ansible_repo_url}" /opt/roboshop-ansible
cd /opt/roboshop-ansible/ansible

if [ "${bootstrap_tier}" != "db" ]; then
  for host in ${wait_hosts}; do
    for attempt in $(seq 1 60); do
      getent hosts "$host" && break 2
      sleep 10
    done
  done
fi

cat > group_vars/all.yml <<EOF
---
artifact_base_url: "${artifact_base_url}"
env: "${env}"
mysql_host: "${mysql_host}"
mongodb_host: "${mongodb_host}"
valkey_host: "${valkey_host}"
rabbitmq_host: "${rabbitmq_host}"
catalogue_host: "${catalogue_host}"
user_host: "${user_host}"
cart_host: "${cart_host}"
shipping_host: "${shipping_host}"
payment_host: "${payment_host}"
notification_host: "${notification_host}"
orders_host: "${orders_host}"
ratings_host: "${ratings_host}"
frontend_host: "${frontend_host}"
EOF

export PATH=/usr/local/bin:/usr/sbin:/usr/bin:$PATH
ansible-playbook -i localhost, -c local main.yml -e "COMPONENT=${component}"
