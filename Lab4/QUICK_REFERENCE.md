# Lab4 Quick Reference

## File Checklist

### Terraform Files Needed
- [ ] `terraform/main.tf` - Libvirt provider, network, cloud-init, VM resources
- [ ] `terraform/variables.tf` - Input variables definition
- [ ] `terraform/outputs.tf` - Worker IP, DB IP outputs
- [ ] `terraform/cloud_init.cfg` - Ansible user bootstrap script
- [ ] `terraform/terraform.tfvars` - Variable values (create from example)

### Ansible Files Needed
- [ ] `ansible/playbook.yml` - Main orchestration playbook
- [ ] `ansible/hosts.ini` - Generated inventory (dynamic from Terraform)

### Ansible Roles - Common
- [ ] `ansible/roles/common/tasks/main.yml`
- [ ] `ansible/roles/common/handlers/main.yml`
- [ ] `ansible/roles/common/vars/main.yml` (optional)
- [ ] `ansible/roles/common/defaults/main.yml` (optional)

### Ansible Roles - Database
- [ ] `ansible/roles/db/tasks/main.yml`
- [ ] `ansible/roles/db/templates/50-server.cnf`
- [ ] `ansible/roles/db/handlers/main.yml`
- [ ] `ansible/roles/db/defaults/main.yml`

### Ansible Roles - Worker
- [ ] `ansible/roles/worker/tasks/main.yml`
- [ ] `ansible/roles/worker/templates/mywebapp.env`
- [ ] `ansible/roles/worker/templates/mywebapp.conf`
- [ ] `ansible/roles/worker/templates/mywebapp.service`
- [ ] `ansible/roles/worker/templates/mywebapp.socket`
- [ ] `ansible/roles/worker/handlers/main.yml`
- [ ] `ansible/roles/worker/defaults/main.yml`

### Support Files
- [ ] `scripts/generate_inventory.sh` - Create hosts.ini from Terraform outputs

### App Assets (Copy from Lab1)
- [ ] `Lab4/app/` - Copy entire mywebapp folder from Lab1

## Key Configuration Values

```yaml
# Database
db_name: notes_db
db_user: app
db_password: app_secure_pass
db_port: 3306

# Application
app_port: 5200
app_user: app
app_dir: /opt/mywebapp
node_version: 22
pnpm_version: latest

# Users & Passwords
teacher_password: 12345678
operator_password: 12345678
ansible_user: ansible (passwordless sudo)

# Paths
gradebook_path: /home/student/gradebook
gradebook_value: 14840136

# Nginx
nginx_listen_port: 80
nginx_proxy_to: 127.0.0.1:5200

# Template Variables
DATABASE_URL: mysql://app:app_secure_pass@{{ db_ip }}:3306/notes_db
BIND_ADDRESS: {{ ansible_default_ipv4.address }}  # VM's internal IP
```

## Ansible Role Structure

Each role follows this structure:
```
roles/ROLENAME/
├── defaults/
│   └── main.yml          # Default variables
├── handlers/
│   └── main.yml          # Handlers (service restarts, etc)
├── tasks/
│   └── main.yml          # Main tasks
├── templates/
│   └── *.j2              # Jinja2 template files
└── vars/
    └── main.yml          # Role-specific variables
```

## Jinja2 Template Variables Available

In templates, use:
- `{{ db_ip }}` - Database VM IP (from group_vars)
- `{{ worker_ip }}` - Worker VM IP
- `{{ ansible_default_ipv4.address }}` - Current host's IP
- `{{ ansible_hostname }}` - Hostname
- `{{ ansible_os_family }}` - OS family (Debian, RedHat, etc)

## UFW Firewall Rules

**Worker VM:**
```bash
ufw allow ssh
ufw allow 80/tcp
```

**Database VM:**
```bash
ufw allow ssh
ufw allow from <worker_ip> to any port 3306
```

## Service Dependencies

**Systemd Service Order:**
- `network.target` → `mariadb.service` → `mywebapp.service` → `nginx.service`

## Testing Commands

```bash
# Test SSH connection
ssh -i ~/.ssh/id_rsa ansible@<worker_ip>

# Test database connection from worker
mysql -h <db_ip> -u app -p'app_secure_pass' notes_db

# Test application health
curl http://<worker_ip>/health/alive
curl http://<worker_ip>/health/ready

# Check gradebook
cat /home/student/gradebook

# Verify idempotency
ansible-playbook -i ansible/hosts.ini ansible/playbook.yml
ansible-playbook -i ansible/hosts.ini ansible/playbook.yml  # Should show 0 changed
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| SSH "Permission denied" | Check SSH key in cloud-init, verify ansible user created |
| Database connection refused | Check UFW rules on DB VM, verify IP in DATABASE_URL |
| App won't start | Check systemd unit syntax, review `journalctl -u mywebapp` |
| Health check fails | Ensure DB is accessible from worker, check `/health/ready` logs |
| Idempotency fails | Ensure all tasks use Ansible modules (no shell/command) |
| Nginx proxy issues | Verify app listening on 5200, check nginx config syntax |

## Variables File Structure

**group_vars/all.yml** (if using):
```yaml
---
db_ip: "{{ groups['db'][0] }}"  # First host in db group
db_port: 3306
db_name: notes_db
db_user: app
db_password: app_secure_pass
```

**hosts.ini** example:
```ini
[all]
worker ansible_host=192.168.122.10 ansible_user=ansible
db ansible_host=192.168.122.11 ansible_user=ansible

[workers]
worker

[db]
db
```

## Helpful Ansible Commands

```bash
# Validate playbook syntax
ansible-playbook --syntax-check ansible/playbook.yml

# Dry-run (check mode)
ansible-playbook -i ansible/hosts.ini ansible/playbook.yml --check

# Run specific role/tag
ansible-playbook -i ansible/hosts.ini ansible/playbook.yml --tags "worker"

# Verbose output
ansible-playbook -i ansible/hosts.ini ansible/playbook.yml -vvv

# Check connectivity
ansible all -i ansible/hosts.ini -m ping
```

## Lab1 Reference Points

From Lab1 docker-compose.yml:
- MariaDB container: `mariadb:11.6`
- App container: Custom build with Node.js
- Nginx config: Routes to app on 127.0.0.1:5200
- Health endpoint protection: `/health` only from localhost
- Database credentials: `MYSQL_USER=app`, `MYSQL_PASSWORD=app_secure_pass`
- Database name: `notes_db`

## Terraform Libvirt Provider Resources

Main resources needed:
- `libvirt_network` - Private network for VMs
- `libvirt_volume` - OS disk images for VMs
- `libvirt_domain` - VM instances
- `libvirt_cloudinit_disk` - Cloud-init configuration disk

## Validation Checklist

Before considering Lab4 complete:
- [ ] Both VMs provision successfully
- [ ] Ansible playbook runs without errors
- [ ] Second playbook run shows "0 changed"
- [ ] SSH connectivity from host to both VMs
- [ ] Database accessibility from worker VM only
- [ ] Application running on worker VM
- [ ] Nginx reverse proxy working
- [ ] `/health/alive` endpoint returns 200
- [ ] `/health/ready` endpoint returns 200 (cross-VM DB connection)
- [ ] Gradebook file exists with correct value
- [ ] Security rules enforced (firewall, user permissions)
