terraform {
  required_version = ">= 1.5.0"

  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # Pinned to the 0.8 series: the 0.9 rewrite of libvirt_domain uses a
      # completely different schema (no disk/network_interface blocks).
      version = ">= 0.8.3, < 0.9.0"
    }
  }
}

provider "libvirt" {
  # Run from an Ubuntu host with the libvirt daemon running.
  # Make sure your user is a member of the libvirt & kvm groups.
  uri = var.libvirt_uri
}
