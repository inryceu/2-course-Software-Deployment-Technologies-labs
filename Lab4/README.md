# Lab №4: Infrastructure as Code with Terraform & Ansible

## Overview
This laboratory deploys the NestJS application from Lab1 across two Ubuntu 24.04 VMs using Infrastructure as Code:
- **terraform/**: Provisions VMs with network isolation
- **ansible/**: Configures application, database, and proxy layers

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Private Network (libvirt)                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────┐          ┌──────────────────────┐  │
│  │  VM1 (worker)          │          │  VM2 (db)            │  │
│  │  Ubuntu 24.04          │          │  Ubuntu 24.04        │  │
│  ├────────────────────────┤          ├──────────────────────┤  │
│  │ • Nginx (port 80)      │          │ • MariaDB (3306)     │  │
│  │ • NestJS app (5200)    │◄────────►│   - notes_db         │  │
│  │ • systemd service      │          │   - app user         │  │
│  │ • pnpm/Node.js 22      │          │                      │  │
│  │                        │          │  (Private to VM1)    │  │
│  └────────────────────────┘          └──────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Terraform**: Installed with libvirt provider support
2. **Ansible**: Installed with Python 3.9+
3. **SSH Key**: Your public SSH key (`~/.ssh/id_rsa.pub`) for cloud-init injection
4. **libvirt**: KVM hypervisor with libvirt daemon running
5. **Ubuntu Cloud Image**: Ubuntu 24.04 cloud image available locally

## Quick Start

### 1. Prepare Variables
Create `terraform/terraform.tfvars`:
```hcl
ssh_public_key = file("~/.ssh/id_rsa.pub")
worker_vcpu    = 4
worker_memory  = 8192
db_vcpu        = 2
db_memory      = 4096
```

### 2. Provision Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This will output:
- `worker_ip`: IP of the worker VM
- `db_ip`: IP of the database VM

### 3. Generate Ansible Inventory
```bash
cd ../scripts
bash generate_inventory.sh
# Outputs: ../ansible/hosts.ini
```

### 4. Run Ansible Playbook
```bash
cd ../ansible
ansible-playbook -i hosts.ini playbook.yml
```

### 5. Verify Deployment
```bash
# SSH to worker VM
ssh -i ~/.ssh/id_rsa ansible@<worker_ip>

# Check health endpoints
curl http://<worker_ip>/health/alive
curl http://<worker_ip>/health/ready

# Verify gradebook
cat /home/student/gradebook  # Should output: 14840136
```

## Users & Credentials

### All VMs
- **ansible** (SSH user, created by cloud-init)
  - Passwordless sudo
  - SSH key-based login

- **teacher** (via Ansible common role)
  - Sudo access
  - Password: `12345678`

### Worker VM
- **app** (system user)
  - Runs NestJS application
  - No login shell

- **operator** (limited sudo)
  - Password: `12345678`
  - Sudo access: `systemctl restart mywebapp`, `nginx -s reload`

### Database VM
- **MariaDB app user**
  - Username: `app`
  - Password: `app_secure_pass`
  - Database: `notes_db`
  - Host restriction: Only connects from worker VM IP

## Firewall Rules

### Worker VM (UFW)
- SSH (22): Allow all
- HTTP (80): Allow all
- Port 5200: Internal only (Nginx proxy)

### Database VM (UFW)
- SSH (22): Allow all
- MariaDB (3306): Allow only from worker VM IP

## File Structure

```
Lab4/
├── terraform/
│   ├── main.tf                  # Libvirt provider, network, VMs
│   ├── outputs.tf               # VM IP addresses
│   ├── variables.tf             # Input variables
│   ├── cloud_init.cfg           # Cloud-init script for ansible user
│   └── terraform.tfvars.example # Example variables file
├── ansible/
│   ├── playbook.yml             # Main orchestration playbook
│   ├── hosts.ini                # Generated inventory (not in repo)
│   ├── roles/
│   │   ├── common/
│   │   │   ├── tasks/main.yml           # Base packages, users, UFW
│   │   │   └── handlers/main.yml        # UFW restart handler
│   │   ├── db/
│   │   │   ├── tasks/main.yml           # MariaDB install/config
│   │   │   ├── templates/50-server.cnf  # MySQL server config
│   │   │   └── handlers/main.yml        # Service restart
│   │   └── worker/
│   │       ├── tasks/main.yml           # Node.js, app, Nginx setup
│   │       ├── templates/
│   │       │   ├── mywebapp.env         # Database URL injection
│   │       │   ├── mywebapp.conf        # Nginx reverse proxy
│   │       │   ├── mywebapp.service     # Systemd unit
│   │       │   └── mywebapp.socket      # Systemd socket
│   │       └── handlers/main.yml        # Service restart handlers
│   └── templates/               # Global templates (if any)
├── scripts/
│   └── generate_inventory.sh    # Create hosts.ini from Terraform outputs
└── README.md                    # This file
```

## Key Configuration Details

### Database Configuration (db role)
- MariaDB 11.6+ (from Ubuntu repos)
- Character set: utf8mb4
- Collation: utf8mb4_unicode_ci
- Bind address: VM's internal IP (not 127.0.0.1)
- User `app` creation: Host restriction to worker VM IP

### Application Configuration (worker role)
- Node.js 22 (from NodeSource repo)
- pnpm (latest stable)
- Application path: `/opt/mywebapp`
- Service user: `app`
- Service port: 5200 (internal)
- `.env` populated with DATABASE_URL: `mysql://app:app_secure_pass@<db_vm_ip>:3306/notes_db`

### Proxy Configuration
- Nginx listens on port 80
- Routes `/api/docs` and `/notes` to `127.0.0.1:5200`
- `/health` endpoint restricted to localhost
- Default route returns 403

## Idempotency

The playbook is fully idempotent:
```bash
# Run once
ansible-playbook -i hosts.ini playbook.yml

# Run again - should show "0 changed"
ansible-playbook -i hosts.ini playbook.yml
```

## Troubleshooting

### SSH Connection Issues
- Ensure `ansible` user was created via cloud-init
- Verify SSH key is in `~/.ssh/id_rsa.pub`
- Check VM IP with: `terraform output worker_ip`

### Database Connection Errors
- Verify database VM IP with: `terraform output db_ip`
- Test from worker: `mysql -h <db_ip> -u app -p'app_secure_pass' notes_db`
- Check firewall rules on DB VM: `sudo ufw status`

### Application Won't Start
- Check logs: `journalctl -u mywebapp -n 50`
- Verify NODE_ENV is set to 'production'
- Check `.env` file: `cat /opt/mywebapp/.env`
- Ensure Prisma migration succeeded

### Health Check Fails
- Test liveness: `curl http://<worker_ip>/health/alive`
- Test readiness: `curl http://<worker_ip>/health/ready`
- Check app logs: `sudo journalctl -u mywebapp -f`

## Security Notes

1. **SSH Keys**: Use key-based authentication; avoid passwords
2. **Database**: MariaDB restricted to private network, accepts only from worker
3. **UFW Rules**: Only necessary ports are exposed
4. **Sudo Access**: `operator` user has minimal required permissions
5. **Cloud-Init**: Ansible user created with strong security; SSH key injection preferred over passwords

## Lab1 Integration

This Lab4 solution uses the NestJS application from Lab1:
- Source copied from: `../Lab1/mywebapp/`
- Configuration templates adapted from Lab1's docker-compose setup
- Health endpoints verified against Lab1's application

## Future Improvements

- [ ] Dynamic inventory script using Terraform state
- [ ] SSL/TLS certificates for Nginx
- [ ] Database backup automation
- [ ] Application monitoring/logging stack
- [ ] Load balancing with multiple worker nodes
- [ ] Container-based deployment (Docker on VMs)

## Support

For issues, refer to:
- Terraform docs: https://registry.terraform.io/providers/dmacvicar/libvirt
- Ansible docs: https://docs.ansible.com/
- Lab1 README: `../Lab1/README.md`
