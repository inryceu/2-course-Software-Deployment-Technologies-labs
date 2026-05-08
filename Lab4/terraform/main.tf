terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1" 
    }
  }
} 

provider "libvirt" {
  uri = "qemu+unix:///system?socket=/var/run/libvirt/libvirt-sock"
}

resource "libvirt_network" "lab4_net" {
  name      = var.network_name
  mode      = "nat"
  addresses = [var.network_cidr]
  autostart = true

  dns {
    enabled = true
    local_only = true
  }
}

resource "libvirt_cloudinit_disk" "common_init" {
  for_each  = toset([var.worker_hostname, var.db_hostname])
  name      = "${each.value}-init.iso"
  user_data = templatefile("${path.module}/cloud_init.cfg", {
    hostname       = each.value
    ssh_public_key = var.ssh_public_key
  })
  meta_data = "" 
}

resource "libvirt_volume" "base_image" {
  name   = "ubuntu-24-04-base"
  pool   = var.storage_pool
  source = var.ubuntu_cloud_image
  format = "qcow2"
}

resource "libvirt_volume" "disks" {
  for_each = {
    worker = var.worker_hostname
    db     = var.db_hostname
  }
  name           = "${each.value}.qcow2"
  pool           = var.storage_pool
  base_volume_id = libvirt_volume.base_image.id 
  format         = "qcow2"
  size           = 10737418240 
}

resource "libvirt_domain" "vms" {
  for_each = {
    worker = { name = var.worker_hostname, mem = var.worker_memory_mb, cpu = var.worker_vcpu }
    db     = { name = var.db_hostname, mem = var.db_memory_mb, cpu = var.db_vcpu }
  }

  name   = each.value.name
  memory = each.value.mem
  vcpu   = each.value.cpu

  cloudinit = libvirt_cloudinit_disk.common_init[each.value.name].id

  network_interface {
    network_id     = libvirt_network.lab4_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.disks[each.key].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}