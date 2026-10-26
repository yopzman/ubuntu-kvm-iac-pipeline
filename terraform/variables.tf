variable "libvirt_uri" {
  type        = string
  description = "URI koneksi libvirt daemon."
  default     = "qemu:///system"
}

variable "cluster_name" {
  type        = string
  description = "Prefiks nama untuk semua resource (domain, volume, cloud-init)."
  default     = "k8s-lab"
}

variable "pool_name" {
  type        = string
  description = "Nama storage pool libvirt untuk disk VM."
  default     = "k8s-lab-vms"
}

variable "pool_path" {
  type        = string
  description = "Direktori di host untuk storage pool libvirt."
  default     = "/var/lib/libvirt/k8s-lab-vms"
}

variable "base_image_path" {
  type        = string
  description = "Path ke golden image hasil Packer."
  default     = "../packer/output-qemu/ubuntu-noble-kvm.qcow2"
}

variable "network_name" {
  type        = string
  description = "Jaringan libvirt untuk NIC VM (DHCP, default 192.168.122.0/24)."
  default     = "default"
}

variable "domain" {
  type        = string
  description = "Suffix DNS lokal untuk FQDN node."
  default     = "lab.local"
}

variable "admin_user" {
  type        = string
  description = "User admin yang dibuat cloud-init di setiap VM (akses SSH key)."
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path public key yang di-inject ke user admin."
  default     = "~/.ssh/id_ed25519.pub"
}

variable "master_count" {
  type        = number
  description = "Jumlah VM master."
  default     = 1
}

variable "worker_count" {
  type        = number
  description = "Jumlah VM worker."
  default     = 2
}

variable "master_vcpu" {
  type        = number
  description = "vCPU per VM master."
  default     = 2
}

variable "master_memory_mb" {
  type        = number
  description = "RAM (MiB) per VM master."
  default     = 4096
}

variable "worker_vcpu" {
  type        = number
  description = "vCPU per VM worker."
  default     = 2
}

variable "worker_memory_mb" {
  type        = number
  description = "RAM (MiB) per VM worker."
  default     = 4096
}
