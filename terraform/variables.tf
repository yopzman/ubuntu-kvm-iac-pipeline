variable "libvirt_uri" {
  type        = string
  description = "libvirt daemon connection URI."
  default     = "qemu:///system"
}

variable "cluster_name" {
  type        = string
  description = "Name prefix for all resources (domains, volumes, cloud-init)."
  default     = "k8s-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.cluster_name))
    error_message = "cluster_name must be lowercase alphanumeric with dashes and start with a letter."
  }
}

variable "pool_name" {
  type        = string
  description = "libvirt storage pool name for VM disks."
  default     = "k8s-lab-vms"
}

variable "pool_path" {
  type        = string
  description = "Host directory backing the libvirt storage pool."
  default     = "/var/lib/libvirt/k8s-lab-vms"
}

variable "base_image_path" {
  type        = string
  description = "Path to the Packer-built golden image."
  default     = "../packer/output-qemu/ubuntu-noble-kvm.qcow2"
}

variable "network_name" {
  type        = string
  description = "libvirt network for VM NICs (DHCP, default 192.168.122.0/24)."
  default     = "default"
}

variable "domain" {
  type        = string
  description = "Local DNS suffix for node FQDNs."
  default     = "lab.local"
}

variable "admin_user" {
  type        = string
  description = "Admin user created by cloud-init on every VM (SSH key access)."
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the public key injected into the admin user."
  default     = "~/.ssh/id_ed25519.pub"
}

variable "master_count" {
  type        = number
  description = "Number of master VMs."
  default     = 1

  validation {
    condition     = var.master_count >= 1
    error_message = "At least one master node is required."
  }
}

variable "worker_count" {
  type        = number
  description = "Number of worker VMs."
  default     = 2

  validation {
    condition     = var.worker_count >= 1
    error_message = "At least one worker node is required."
  }
}

variable "master_vcpu" {
  type        = number
  description = "vCPUs per master VM."
  default     = 2

  validation {
    condition     = var.master_vcpu >= 1
    error_message = "master_vcpu must be at least 1."
  }
}

variable "master_memory_mb" {
  type        = number
  description = "RAM (MiB) per master VM."
  default     = 4096

  validation {
    condition     = var.master_memory_mb >= 1024
    error_message = "master_memory_mb must be at least 1024 MiB."
  }
}

variable "worker_vcpu" {
  type        = number
  description = "vCPUs per worker VM."
  default     = 2

  validation {
    condition     = var.worker_vcpu >= 1
    error_message = "worker_vcpu must be at least 1."
  }
}

variable "worker_memory_mb" {
  type        = number
  description = "RAM (MiB) per worker VM."
  default     = 4096

  validation {
    condition     = var.worker_memory_mb >= 1024
    error_message = "worker_memory_mb must be at least 1024 MiB."
  }
}
