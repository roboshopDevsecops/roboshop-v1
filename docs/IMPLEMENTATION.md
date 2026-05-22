# RoboShop v1 — Implementation Context

This document preserves design decisions and implementation details for future maintainers. It supplements `requirements.md` and `README.md`.

---

## Project goal

Deploy the [RoboShop microservices](https://github.com/raghudevopsb88/roboshop-microservices-documentation) e-commerce platform on AWS using:

- **Terraform** for VPC + 13 EC2 instances
- **Ansible** for OS and application configuration
- **User-data** to trigger Ansible automatically on each instance at boot

Everything lives in a **single monorepo** (`roboshop-v1`).

---

## Why three Terraform tiers (`ec2_db`, `ec2_app`, `ec2_frontend`)

Microservices depend on databases and each other. If all 13 instances boot and run Ansible simultaneously:

- App roles may fail when MySQL/MongoDB are not ready.
- Frontend Nginx may point at services that are still installing.

**Solution:** Three wrapper modules using `depends_on`:

```
ec2_db  →  ec2_app  →  ec2_frontend
```

Terraform creates DB instances first, then app instances, then frontend. User-data in each tier waits for prior-tier private DNS names before running Ansible.

---

## Why private Route53 zone

Early design passed every instance’s private IP into every other instance’s user-data via `templatefile()`. That caused **circular Terraform dependencies** (instance A’s user-data needed B’s IP while B needed A’s).

**Solution:** Static hostnames in a private zone `dev.roboshop.internal`:

| DNS name | Points to |
|----------|-----------|
| `mysql.dev.roboshop.internal` | mysql instance |
| `catalogue.dev.roboshop.internal` | catalogue instance |
| … | … |

User-data and Ansible use hostnames only. Route53 A records are created per tier in `ec2_fleet`.

---

## Module responsibilities

### `modules/vpc`

- `aws_vpc`
- Subnets: `public`, `app`, `db` (multi-AZ using `count`)
- Internet Gateway + public route `0.0.0.0/0`
- NAT Gateway (in public subnet) + NAT routes on **app** and **db** route tables
- DB subnets get NAT so `dnf install` / `git clone` work during bootstrap

### `modules/ec2`

- Single `aws_instance`
- `user_data_base64` from template `user-data.sh.tpl`
- Inputs: AMI, subnet, security groups, `component`, credentials

### `modules/ec2_fleet`

- `for_each` over a tier’s instance map
- Calls `modules/ec2` per instance
- Creates `aws_route53_record` per instance
- Outputs `private_ips` / `public_ips` maps

### Root `main.tf`

- Security groups: `frontend`, `app`, `db`
- Wires three fleet modules with `depends_on`
- Merges outputs for `instance_private_ips`

---

## Security groups summary

| SG | Ingress |
|----|---------|
| frontend | 80 from `0.0.0.0/0`, 22 from `0.0.0.0/0` |
| app | 8000–8099 from VPC CIDR, 22 from `0.0.0.0/0` |
| db | 3306, 27017, 6379, 5672, 15672 from VPC CIDR, 22 from `0.0.0.0/0` |

Egress: all protocols to `0.0.0.0/0` on every SG.

---

## User-data script flow

File: `terraform/modules/ec2/user-data.sh.tpl`

| Step | Action |
|------|--------|
| 1 | Log to `/var/log/user-data.log` |
| 2 | `setenforce 0`, disable firewalld |
| 3 | `chpasswd` for `ec2-user` / `DevOps321`, enable `PasswordAuthentication` |
| 4 | Install git, ansible-core, pip |
| 5 | Wait for internet (ping 8.8.8.8) |
| 6 | `git clone` monorepo to `/opt/roboshop-ansible` |
| 7 | If not DB tier: wait for `getent hosts` on dependency DNS names |
| 8 | Write `ansible/group_vars/all.yml` |
| 9 | `ansible-playbook -i localhost, -c local main.yml -e COMPONENT=...` |

**Important:** Push the repo to GitHub before `terraform apply`. User-data clones from `ansible_repo_url` in tfvars.

---

## Ansible design

### Entry playbook

`ansible/main.yml`:

```yaml
roles:
  - common
  - "{{ COMPONENT }}"
```

### Common role

- SELinux permissive
- Firewalld stopped/disabled

### Service roles

Each role follows the official microservices documentation:

1. Install runtime (Node, Go, Java, Python, etc.)
2. Download artifact zip from `artifact_base_url`
3. Configure database on remote host where needed (`mysql_host`, etc.)
4. Create `appuser`, systemd unit from Jinja2 template
5. Start service

### Frontend special case

- Builds Next.js static export on the server
- Nginx `nginx.conf.j2` proxies `/api/*` to private DNS hostnames of backend services

### Group variables

Default placeholders in `ansible/group_vars/all.yml` are overwritten at boot by user-data with real private DNS names.

---

## Variable reference (`terraform/environments/dev/main.tfvars`)

| Variable | Value | Notes |
|----------|-------|-------|
| `ami_id` | `ami-0220d79f3f480ecf5` | Agreed AMI |
| `ec2_user` | `ec2-user` | |
| `ec2_password` | `DevOps321` | Sensitive in Terraform |
| SSH | `ec2-user` / `DevOps321` | No key pair; password set in user-data |
| `ansible_repo_url` | GitHub monorepo URL | Must be reachable from instances |
| `db_instances` | mysql, mongodb, valkey, rabbitmq | Tier 1 |
| `app_instances` | 8 microservices | Tier 2 |
| `frontend_instances` | frontend | Tier 3 |

---

## Terraform outputs

| Output | Description |
|--------|-------------|
| `frontend_public_ip` | Storefront URL |
| `instance_private_ips` | All 13 private IPs |
| `db_private_ips` | Tier 1 only |
| `app_private_ips` | Tier 2 only |
| `instance_dns_names` | Map of `name` → FQDN |
| `private_dns_zone` | `dev.roboshop.internal` |

---

## Running Ansible from jump EC2

After infrastructure is up, re-configure a host without re-running Terraform:

```bash
cd ansible
make remote HOST=catalogue.dev.roboshop.internal COMPONENT=catalogue
```

Uses `ansible_user=ec2-user`, `ansible_password=DevOps321`, `ansible_connection=ssh`.

---

## Ansible failure risks (and mitigations)

| Risk | Roles affected | Mitigation in repo |
|------|----------------|-------------------|
| `unarchive` dest dir missing | All app roles + frontend | `common/tasks/deploy-artifact.yml` creates `/app` first; frontend creates `/tmp/frontend-build` |
| MySQL not ready when app runs SQL | catalogue, shipping, ratings | `common/tasks/wait-for-mysql.yml` |
| MongoDB not ready | user, orders | `common/tasks/wait-for-mongodb.yml` |
| Valkey not ready | cart | `common/tasks/wait-for-valkey.yml` |
| RabbitMQ not ready | payment, orders | `common/tasks/wait-for-rabbitmq.yml` |
| mysqld not listening during root setup | mysql | `wait_for` port 3306 before SQL |
| Service runs as `appuser` but files owned by root | All app roles | `common/tasks/app-permissions.yml` |
| `npm` / `mvn` needs internet | frontend, node/java roles | NAT Gateway on app/db subnets |
| DNS host not resolved at boot | App/frontend tiers | User-data waits for prior-tier DNS; Terraform tier order |

**Remaining timing risks:** `payment` expects cart and user HTTP APIs — tier order does not wait for those services to finish Ansible. If payment fails, re-run: `make remote HOST=payment... COMPONENT=payment`.

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| User-data failed | `sudo cat /var/log/user-data.log` on instance |
| Ansible can’t resolve DB host | Route53 records / tier order; `dig mysql.dev.roboshop.internal` |
| Service won’t start | `journalctl -u <service> -f` |
| Frontend loads, APIs fail | Backend tier still installing; re-run role after DB is up |
| Git clone fails in user-data | Repo not pushed / wrong `ansible_repo_url` / no NAT |
| Terraform state lock | S3 backend; ensure jump box has access |

---

## File change history (conceptual)

| Area | What was built |
|------|----------------|
| Initial | `vpc` + `ec2` modules, 13 instances, Ansible roles, user-data |
| Refinement | Tiered `ec2_fleet`, private DNS, boot order |
| Credentials | `ec2-user` / `DevOps321`, AMI update, SSH 0.0.0.0/0 |
| Docs | `requirements.md`, `README.md`, this file |

---

## Possible future improvements

1. Add `environments/prod/` with stricter `ssh_cidr_blocks`.
2. Use AWS Secrets Manager for `ec2_password` and DB passwords.
3. Replace git clone in user-data with S3 artifact of ansible tarball (no GitHub dependency at boot).
4. Add `null_resource` or Step Functions to re-run Ansible in dependency order after all instances are up.
5. Enable HTTPS with ACM + ALB in front of frontend.
