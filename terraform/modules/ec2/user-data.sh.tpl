#!/bin/bash
set -euxo pipefail

exec > /var/log/user-data.log 2>&1

setenforce 0 || true
systemctl stop firewalld || true
systemctl disable firewalld || true

echo "${ec2_user}:${ec2_password}" | chpasswd
if [ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]; then
  sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf
fi
grep -q '^PasswordAuthentication' /etc/ssh/sshd_config \
  && sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
  || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
systemctl restart sshd

dnf install -y git ansible-core python3-pip

for attempt in $(seq 1 30); do
  ping -c1 -W2 8.8.8.8 && break
  sleep 10
done

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

ansible-playbook -i localhost, -c local main.yml -e "COMPONENT=${component}"
