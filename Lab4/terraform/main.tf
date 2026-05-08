terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

locals {
  cloud_init_worker = templatefile("${path.module}/cloud_init.cfg", {
    hostname       = var.worker_hostname
    ssh_public_key = var.ssh_public_key
  })

  cloud_init_db = templatefile("${path.module}/cloud_init.cfg", {
    hostname       = var.db_hostname
    ssh_public_key = var.ssh_public_key
  })
}

resource "libvirt_network" "lab4_net" {
  name      = var.network_name
  mode      = "nat"
  domain    = var.network_domain
  addresses = [var.network_cidr]
  autostart = true
}

resource "libvirt_cloudinit_disk" "worker_init" {
  name      = "${var.worker_hostname}-cloud-init.iso"
  pool      = var.storage_pool
  user_data = local.cloud_init_worker
}

resource "libvirt_cloudinit_disk" "db_init" {
  name      = "${var.db_hostname}-cloud-init.iso"
  pool      = var.storage_pool
  user_data = local.cloud_init_db
}

resource "libvirt_volume" "worker_disk" {
  name   = "${var.worker_hostname}.qcow2"
  pool   = var.storage_pool
  source = var.ubuntu_cloud_image
  format = "qcow2"
}

resource "libvirt_volume" "db_disk" {
  name   = "${var.db_hostname}.qcow2"
  pool   = var.storage_pool
  source = var.ubuntu_cloud_image
  format = "qcow2"
}

resource "libvirt_domain" "worker" {
  name      = var.worker_hostname
  memory    = var.worker_memory_mb
  vcpu      = var.worker_vcpu
  autostart = true
  cloudinit = libvirt_cloudinit_disk.worker_init.id

  network_interface {
    network_id     = libvirt_network.lab4_net.id
    hostname       = var.worker_hostname
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "none"
    autoport    = true
  }
}

resource "libvirt_domain" "db" {
  name      = var.db_hostname
  memory    = var.db_memory_mb
  vcpu      = var.db_vcpu
  autostart = true
  cloudinit = libvirt_cloudinit_disk.db_init.id

  network_interface {
    network_id     = libvirt_network.lab4_net.id
    hostname       = var.db_hostname
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.db_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "none"
    autoport    = true
  }
}
