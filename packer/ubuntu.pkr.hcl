packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Build variables
# ---------------------------------------------------------------------------

variable "ubuntu_version" {
  type        = string
  default     = "24.04.5"
  description = "Ubuntu Server LTS point release used as the ISO source."
}

variable "iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/noble/ubuntu-24.04.5-live-server-amd64.iso"
  description = "Ubuntu live-server ISO URL (override for a newer point release)."
}

variable "iso_checksum" {
  type        = string
  default     = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
  description = "ISO checksum (file: prefix auto-matches the ISO name against SHA256SUMS)."
}

variable "disk_size" {
  type        = string
  default     = "20G"
  description = "Root disk size of the golden image."
}

variable "memory" {
  type        = number
  default     = 4096
  description = "RAM (MiB) for the builder VM during installation."
}

variable "cpus" {
  type        = number
  default     = 2
  description = "Number of vCPUs for the builder VM."
}

variable "ssh_username" {
  type        = string
  default     = "packer"
  description = "Temporary user created by autoinstall for Packer access."
}

variable "ssh_password" {
  type        = string
  default     = "packer"
  description = "Password for the temporary user (its hash is embedded in http/user-data)."
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

  # Autoinstall is fetched from Packer's built-in HTTP server (http/ directory):
  # ds=nocloud-net reads user-data + meta-data from s=http://<host>:<port>/
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
# Build: OS updates, bake the baseline with Ansible, write the manifest
# ---------------------------------------------------------------------------

build {
  sources = ["source.qemu.ubuntu"]

  # OS updates only - packages and hardening are handled by the
  # autoinstall file and the Ansible provisioner below.
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    inline = [
      "apt-get update",
      "apt-get -y dist-upgrade",
      "apt-get -y autoremove",
      "apt-get clean",
    ]
  }

  # Bake the baseline roles (common + hardening) into the image.
  # Requires ansible and sshpass on the build host (password communicator).
  provisioner "ansible" {
    playbook_file = "../ansible/image-bake.yml"
    extra_arguments = [
      "-e",
      "ansible_ssh_common_args=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
    ]
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
