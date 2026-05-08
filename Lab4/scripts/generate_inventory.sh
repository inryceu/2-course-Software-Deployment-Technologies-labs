#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/../ansible"
OUT_FILE="${ANSIBLE_DIR}/hosts.ini"

worker_ip="$(terraform -chdir="${TERRAFORM_DIR}" output -raw worker_ip)"
db_ip="$(terraform -chdir="${TERRAFORM_DIR}" output -raw db_ip)"

cat > "${OUT_FILE}" <<EOF
[workers]
worker ansible_host=${worker_ip}

[db]
db ansible_host=${db_ip}

[all:vars]
ansible_user=ansible
ansible_python_interpreter=/usr/bin/python3
EOF

echo "Inventory generated at ${OUT_FILE}"
