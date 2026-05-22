# RoboShop v1 — Requirements

This document captures the original requirements, additional decisions made during implementation, and what was delivered in this repository.

---

## 1. Original Requirements

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Write Terraform code to create all **13 instances** in AWS | Done |
| 2 | Terraform with **2 core modules**: `vpc` and `ec2` | Done (+ `ec2_fleet` wrapper for boot tiers) |
| 3 | VPC with **three subnet types**: public (frontend + public IP), app (microservices), db (databases/broker) | Done |
| 4 | **Internet** for private subnets via **NAT Gateway** | Done (app + db subnets) |
| 5 | Terraform structure like [wmp-terraform-encrypt-n-network-v9](https://github.com/raghudevopsb88/wmp-terraform-encrypt-n-network-v9) | Done |
| 6 | Ansible from [roboshop-microservices-documentation](https://github.com/raghudevopsb88/roboshop-microservices-documentation), structure like [wmp-ansible-v4](https://github.com/raghudevopsb88/wmp-ansible-v4) | Done |
| 7 | Every EC2 instance uses **user-data** to run the respective **Ansible role** | Done |

---

## 2. Additional Requirements (Agreed During Implementation)

| # | Requirement | Status |
|---|-------------|--------|
| 8 | **Single monorepo** — Terraform and Ansible in one Git repository | Done |
| 9 | Run Terraform from a **jump EC2** box that has an IAM role (not from laptop only) | Documented |
| 10 | OS user: **`ec2-user`**, password: **`DevOps321`** (SSH password auth enabled via user-data) | Done |
| 11 | AMI: **`ami-0220d79f3f480ecf5`** | Done (`terraform/environments/dev/main.tfvars`) |
| 12 | **SSH** allowed from **`0.0.0.0/0`** on all instances | Done |
| 13 | **Boot order** enforced by Terraform module dependencies: **DB → App → Frontend** | Done |

---

## 3. Infrastructure Specification

### 3.1 Repository layout

```text
roboshop-v1/
├── requirements.md          # This file
├── README.md                # Quick start and operations guide
├── docs/
│   └── IMPLEMENTATION.md    # Detailed design and decisions for future reference
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── state.tf
│   ├── Makefile
│   ├── environments/dev/
│   │   ├── main.tfvars
│   │   └── state.tfvars
│   └── modules/
│       ├── vpc/             # VPC, subnets, IGW, NAT, route tables
│       ├── ec2/             # Single EC2 + user-data template
│       └── ec2_fleet/       # Tier wrapper (multiple EC2 + Route53 records)
└── ansible/
    ├── main.yml
    ├── Makefile
    ├── group_vars/all.yml
    └── roles/               # One role per component (13 roles)
```

### 3.2 Terraform modules

| Module | Purpose |
|--------|---------|
| `modules/vpc` | VPC, public/app/db subnets, Internet Gateway, NAT Gateway, route tables |
| `modules/ec2` | Single EC2 instance, user-data bootstrap, root volume |
| `modules/ec2_fleet` | Deploys a map of instances + private DNS A records for one boot tier |

### 3.3 Boot tiers (order of creation)

Terraform applies instances in this order using `depends_on`:

| Tier | Module | Instances | Subnet |
|------|--------|-----------|--------|
| 1 — DB | `ec2_db` | mysql, mongodb, valkey, rabbitmq | db |
| 2 — App | `ec2_app` | catalogue, user, cart, shipping, payment, notification, orders, ratings | app |
| 3 — Frontend | `ec2_frontend` | frontend | public (with public IP) |

**Note:** Valkey is the RHEL 10 replacement for Redis (same port 6379, Redis protocol).

### 3.4 Network (dev environment)

| Setting | Value |
|---------|-------|
| VPC CIDR | `10.20.0.0/24` |
| Region | `us-east-1` |
| Public subnets | `10.20.0.0/27`, `10.20.0.32/27` |
| DB subnets | `10.20.0.64/27`, `10.20.0.96/27` |
| App subnets | `10.20.0.128/26`, `10.20.0.192/26` |
| Private DNS zone | `dev.roboshop.internal` |
| NAT | One NAT Gateway per public subnet; routes on app + db subnets |

### 3.5 All 13 servers

| Server | Instance name | Subnet | Technology | Port |
|--------|---------------|--------|------------|------|
| 1 | frontend | public | Nginx + Next.js static | 80 |
| 2 | mysql | db | MySQL 8.4 | 3306 |
| 3 | catalogue | app | Go | 8002 |
| 4 | mongodb | db | MongoDB 7 | 27017 |
| 5 | user | app | Node.js | 8001 |
| 6 | valkey | db | Valkey (Redis-compatible) | 6379 |
| 7 | cart | app | Node.js | 8003 |
| 8 | shipping | app | Java 21 | 8004 |
| 9 | rabbitmq | db | RabbitMQ | 5672 / 15672 |
| 10 | payment | app | Python / FastAPI | 8005 |
| 11 | notification | app | Python / Flask | 8008 |
| 12 | orders | app | Java 21 | 8007 |
| 13 | ratings | app | Python / Flask | 8006 |

Instance type for all: **`t3.small`**.

### 3.6 Access and credentials

| Setting | Value |
|---------|-------|
| SSH user | `ec2-user` |
| SSH password | `DevOps321` |
| SSH CIDR | `0.0.0.0/0` |
| SSH key pair | **None** — password authentication only (set in user-data) |
| AMI | `ami-0220d79f3f480ecf5` |
| DB passwords (app) | `RoboShop@1` (per microservices documentation) |

### 3.7 State backend

| Setting | Value |
|---------|-------|
| Backend | S3 |
| Bucket | `terraform-state-d88` |
| State key | `roboshop-v1/dev/terraform.tfstate` |
| Region | `us-east-1` |

---

## 4. Ansible Specification

### 4.1 Pattern

- Entry point: `ansible/main.yml` — runs `common` role then `{{ COMPONENT }}` role.
- One role per server component (13 roles under `ansible/roles/`).
- Artifacts downloaded from:  
  `https://raw.githubusercontent.com/raghudevopsb88/roboshop-microservices-documentation/main/artifacts`

### 4.2 Roles

| Role | Installs / configures |
|------|------------------------|
| `common` | SELinux permissive, firewalld disabled |
| `frontend` | Nginx, Node.js 20, builds static frontend, API gateway nginx.conf |
| `mysql` | MySQL 8.4, root remote access |
| `mongodb` | MongoDB 7, bind 0.0.0.0 |
| `valkey` | Valkey, remote access |
| `rabbitmq` | Erlang + RabbitMQ, management plugin, `roboshop` user |
| `catalogue` | Go build, MySQL schema, systemd |
| `user` | Node.js app, systemd |
| `cart` | Node.js app, systemd |
| `shipping` | Java/Maven build, MySQL schema, systemd |
| `payment` | Python/pip, systemd |
| `notification` | Python/pip, systemd |
| `orders` | Java/Maven build, systemd |
| `ratings` | Python/pip, MySQL schema, systemd |

### 4.3 Service discovery

Private hostnames (Route53) are written to `group_vars/all.yml` by user-data:

- `mysql.dev.roboshop.internal`
- `mongodb.dev.roboshop.internal`
- `valkey.dev.roboshop.internal`
- `rabbitmq.dev.roboshop.internal`
- `catalogue.dev.roboshop.internal`
- … (one record per instance)

Nginx on the frontend proxies `/api/*` to these hostnames.

---

## 5. User-Data Behaviour

On first boot each instance:

1. Disables SELinux enforcement and firewalld.
2. Sets `ec2-user` password to `DevOps321` and enables SSH password authentication.
3. Installs `git`, `ansible-core`, `python3-pip`.
4. Waits for internet connectivity.
5. Clones this repo: `https://github.com/raghudevopsb88/roboshop-v1.git`
6. Waits for required private DNS hosts (tier-dependent):
   - **DB tier:** no DNS wait
   - **App tier:** waits for mysql, mongodb, valkey, rabbitmq
   - **Frontend tier:** waits for DB + all app hosts
7. Writes `ansible/group_vars/all.yml` with service hostnames.
8. Runs `ansible-playbook main.yml -e COMPONENT=<role>` locally.

Logs: `/var/log/user-data.log`

---

## 6. Deployment Workflow

### Prerequisites

1. Push this repository to GitHub (user-data clones it at apply time).
2. Jump EC2 with IAM role: VPC, EC2, Route53, S3 permissions.
3. S3 bucket `terraform-state-d88` exists.
4. No EC2 key pair required — SSH uses `ec2-user` / `DevOps321` only.

### Commands (on jump EC2)

```bash
git clone https://github.com/raghudevopsb88/roboshop-v1.git
cd roboshop-v1/terraform
make dev-apply
terraform output frontend_public_ip
```

### Verify

- Browser: `http://<frontend-public-ip>`
- SSH: `ssh ec2-user@<instance-ip>` (password: `DevOps321`)
- User-data log: `sudo tail -f /var/log/user-data.log`

---

## 7. Reference Repositories

| Repo | Used for |
|------|----------|
| [wmp-terraform-encrypt-n-network-v9](https://github.com/raghudevopsb88/wmp-terraform-encrypt-n-network-v9) | Terraform folder layout, VPC module pattern, Makefile, S3 backend |
| [wmp-ansible-v4](https://github.com/raghudevopsb88/wmp-ansible-v4) | Ansible `main.yml` + `COMPONENT` variable, Makefile, role layout |
| [roboshop-microservices-documentation](https://github.com/raghudevopsb88/roboshop-microservices-documentation) | Per-service install steps, artifacts, ports, dependencies |

---

## 8. Out of Scope (Current Version)

- Production hardening (SELinux policies, restricted security groups, secrets manager).
- TLS / HTTPS on frontend.
- Auto Scaling Groups or load balancers.
- CI/CD pipeline.
- Staging/prod environments (only `dev` tfvars provided; pattern supports adding `environments/prod/`).
