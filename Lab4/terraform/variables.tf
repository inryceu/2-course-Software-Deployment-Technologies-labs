variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "storage_pool" {
  description = "Libvirt storage pool name for VM disks and cloud-init images"
  type        = string
  default     = "default"
}

variable "ubuntu_cloud_image" {
  description = "Absolute path to Ubuntu 24.04 cloud image qcow2 file"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to inject for ansible user"
  type        = string
}

variable "network_name" {
  description = "Libvirt network name"
  type        = string
  default     = "lab4-network"
}

variable "network_domain" {
  description = "Local network domain"
  type        = string
  default     = "lab4.local"
}

variable "network_cidr" {
  description = "Private network CIDR for worker-db communication"
  type        = string
  default     = "192.168.150.0/24"
}

variable "worker_hostname" {
  description = "Worker VM hostname"
  type        = string
  default     = "worker"
}

variable "db_hostname" {
  description = "Database VM hostname"
  type        = string
  default     = "db"
}

variable "worker_memory_mb" {
  description = "Worker VM memory (MiB)"
  type        = number
  default     = 4096
}

variable "worker_vcpu" {
  description = "Worker VM vCPU count"
  type        = number
  default     = 2
}

variable "db_memory_mb" {
  description = "DB VM memory (MiB)"
  type        = number
  default     = 2048
}

variable "db_vcpu" {
  description = "DB VM vCPU count"
  type        = number
  default     = 2
}
