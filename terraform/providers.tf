terraform {
  required_version = ">= 1.5.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8"
    }
  }
}

provider "libvirt" {
  # Jalankan dari host Ubuntu dengan libvirt daemon aktif.
  # Pastikan user Anda tergabung di grup libvirt & kvm.
  uri = var.libvirt_uri
}
