# RoboShop v1

Infrastructure-as-code for the [RoboShop microservices](https://github.com/raghudevopsb88/roboshop-microservices-documentation) platform on AWS.

**Terraform** provisions the network and 13 EC2 instances. **Ansible** installs and configures each component. **User-data** runs Ansible automatically at boot.

| Document | Purpose |
|----------|---------|
| [requirements.md](requirements.md) | Full requirements (original + agreed) and specification |
| [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) | Design decisions and troubleshooting for future maintainers |

---

## Repository layout

```text
roboshop-v1/
├── requirements.md
├── README.md
├── docs/IMPLEMENTATION.md
├── terraform/                 # AWS infrastructure
│   ├── modules/vpc/
│   ├── modules/ec2/
│   ├── modules/ec2_fleet/   # Tiered instance groups
│   └── environments/dev/
└── ansible/                 # Configuration management
    ├── main.yml
    └── roles/               # 13 component roles
```

---

## Architecture

```text
                         Internet
                             |
                    +--------+--------+
                    |    Frontend     |  public subnet (public IP)
                    |  Nginx + static |
                    +--------+--------+
                             |  /api/* proxy
         +-------------------+-------------------+
         |                                       |
  +------+------+  app subnets            +------+------+
  | catalogue   |  user, cart, shipping   |    mysql     |  db subnets
  | payment     |  notification, orders    |   mongodb    |
  | ratings     |  ...                     |   valkey     |
  +-------------+                          |   rabbitmq   |
                                           +--------------+
                                                    ^
                                              NAT Gateway
```

**Private DNS:** `dev.roboshop.internal` — each instance gets `<name>.dev.roboshop.internal`.

---

## Quick reference

| Item | Value |
|------|-------|
| Instances | 13 × `t3.small` |
| AMI | `ami-0220d79f3f480ecf5` |
| Region | `us-east-1` |
| SSH user | `ec2-user` |
| SSH password | `DevOps321` |
| SSH from | `0.0.0.0/0` |
| Key pair | `roboshop-key` |
| State bucket | `terraform-state-d88` |
| Git repo (user-data) | `https://github.com/raghudevopsb88/roboshop-v1.git` |

---

## Boot order

Terraform applies three tiers in sequence:

| Order | Module | Instances |
|-------|--------|-----------|
| 1 | `ec2_db` | mysql, mongodb, valkey, rabbitmq |
| 2 | `ec2_app` | catalogue, user, cart, shipping, payment, notification, orders, ratings |
| 3 | `ec2_frontend` | frontend |

---

## All 13 servers

| # | Instance | Subnet | Role |
|---|----------|--------|------|
| 1 | frontend | public | Nginx + Next.js UI |
| 2 | mysql | db | MySQL 8.4 |
| 3 | catalogue | app | Catalogue (Go) :8002 |
| 4 | mongodb | db | MongoDB 7 :27017 |
| 5 | user | app | User (Node.js) :8001 |
| 6 | valkey | db | Valkey / Redis :6379 |
| 7 | cart | app | Cart (Node.js) :8003 |
| 8 | shipping | app | Shipping (Java) :8004 |
| 9 | rabbitmq | db | RabbitMQ :5672 |
| 10 | payment | app | Payment (Python) :8005 |
| 11 | notification | app | Notification (Python) :8008 |
| 12 | orders | app | Orders (Java) :8007 |
| 13 | ratings | app | Ratings (Python) :8006 |

---

## Prerequisites

1. AWS account; jump EC2 with IAM role (VPC, EC2, Route53, S3).
2. S3 bucket `terraform-state-d88` (or edit `terraform/environments/dev/state.tfvars`).
3. Key pair `roboshop-key` in `us-east-1`.
4. **Push this repo to GitHub** before apply (user-data clones it).
5. Terraform and Git installed on jump EC2.

---

## Deploy (from jump EC2)

```bash
git clone https://github.com/raghudevopsb88/roboshop-v1.git
cd roboshop-v1/terraform
make dev-plan     # optional
make dev-apply
```

Outputs:

```bash
terraform output frontend_public_ip
terraform output instance_private_ips
terraform output instance_dns_names
```

Open the storefront: `http://<frontend-public-ip>`

User-data log on any instance:

```bash
sudo tail -f /var/log/user-data.log
```

---

## Ansible (manual re-run)

From jump EC2 against a running host:

```bash
cd ansible
make remote HOST=catalogue.dev.roboshop.internal COMPONENT=catalogue
```

Run all database roles in order (if re-provisioning):

```bash
make databases    # mysql, mongodb, valkey, rabbitmq
make apps         # all app servers
make frontend     # frontend last
```

---

## Terraform Makefile targets

| Target | Action |
|--------|--------|
| `make dev-plan` | Plan with dev tfvars |
| `make dev-apply` | Apply dev environment |
| `make dev-destroy` | Destroy dev environment |

---

## Reference repositories

- Terraform layout: [wmp-terraform-encrypt-n-network-v9](https://github.com/raghudevopsb88/wmp-terraform-encrypt-n-network-v9)
- Ansible layout: [wmp-ansible-v4](https://github.com/raghudevopsb88/wmp-ansible-v4)
- Service docs: [roboshop-microservices-documentation](https://github.com/raghudevopsb88/roboshop-microservices-documentation)
