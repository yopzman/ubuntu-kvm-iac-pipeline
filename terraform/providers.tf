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
  # Run from an Ubuntu host with the libvirt daemon running.
  # Make sure your user is a member of the libvirt & kvm groups.
  uri = var.libvirt_uri
}
