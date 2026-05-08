output "worker_ip" {
  description = "IPv4 address of the worker VM"
  value       = libvirt_domain.worker.network_interface[0].addresses[0]
}

output "db_ip" {
  description = "IPv4 address of the database VM"
  value       = libvirt_domain.db.network_interface[0].addresses[0]
}

output "ansible_inventory_hint" {
  description = "Quick hint to build Ansible inventory groups"
  value = {
    workers = [libvirt_domain.worker.network_interface[0].addresses[0]]
    db      = [libvirt_domain.db.network_interface[0].addresses[0]]
  }
}
