packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Variabel build
# ---------------------------------------------------------------------------

variable "ubuntu_version" {
  type        = string
  default     = "24.04.2"
  description = "Point release Ubuntu Server LTS yang dipakai sebagai sumber ISO."
}

variable "iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/noble/ubuntu-24.04.2-live-server-amd64.iso"
  description = "URL ISO Ubuntu live-server (override untuk point release lebih baru)."
}

variable "iso_checksum" {
  type        = string
  default     = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
  description = "Checksum file ISO (format file: agar otomatis dicocokkan dari SHA256SUMS)."
}

variable "disk_size" {
  type        = string
  default     = "20G"
  description = "Ukuran disk root golden image."
}

variable "memory" {
  type        = number
  default     = 4096
  description = "RAM (MiB) untuk VM builder saat proses instalasi."
}

variable "cpus" {
  type        = number
  default     = 2
  description = "Jumlah vCPU untuk VM builder."
}

variable "ssh_username" {
  type        = string
  default     = "packer"
  description = "User sementara yang dibuat autoinstall untuk akses Packer."
}

variable "ssh_password" {
  type        = string
  default     = "packer"
  description = "Password user sementara (hash-nya tertanam di http/user-data)."
}

# ---------------------------------------------------------------------------
# Source: QEMU/KVM + Ubuntu live-server autoinstall
# ---------------------------------------------------------------------------

source "qemu" "ubuntu" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = "output-qemu"
  vm_name          = "ubuntu-noble-kvm.qcow2"

  format      = "qcow2"
  accelerator = "kvm"
  disk_size   = var.disk_size
  cpus        = var.cpus
  memory      = var.memory
  headless    = true

  # Autoinstall diambil dari HTTP server bawaan Packer (direktori http/):
  # ds=nocloud-net membaca user-data + meta-data dari s=http://<host>:<port>/
  http_directory = "http"
  boot_wait      = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>",
  ]

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "45m"

  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
}

# ---------------------------------------------------------------------------
# Build: update paket, lalu tulis manifest
# ---------------------------------------------------------------------------

build {
  sources = ["source.qemu.ubuntu"]

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    inline = [
      "apt-get update",
      "apt-get -y dist-upgrade",
      "apt-get -y install qemu-guest-agent python3",
      "apt-get -y autoremove",
      "apt-get clean",
    ]
  }

  post-processor "manifest" {
    output_file = "packer-manifest.json"
  }
}
