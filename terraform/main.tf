# ---------------------------------------------------------------------------
# Node definitions: 1 master + N workers
# ---------------------------------------------------------------------------

locals {
  masters = {
    for idx in range(var.master_count) : "master-${idx + 1}" => {
      role   = "master"
      vcpu   = var.master_vcpu
      memory = var.master_memory_mb
    }
  }

  workers = {
    for idx in range(var.worker_count) : "worker-${idx + 1}" => {
      role   = "worker"
      vcpu   = var.worker_vcpu
      memory = var.worker_memory_mb
    }
  }

  nodes = merge(local.masters, local.workers)
}

# ---------------------------------------------------------------------------
# Storage pool & golden image from Packer
# ---------------------------------------------------------------------------

resource "libvirt_pool" "vms" {
  name = var.pool_name
  type = "dir"
  path = var.pool_path
}

resource "libvirt_volume" "base" {
  name   = "${var.pool_name}-base.qcow2"
  pool   = libvirt_pool.vms.name
  source = var.base_image_path
  format = "qcow2"
}

# ---------------------------------------------------------------------------
# Per-node cloud-init (hostname + admin user + SSH key)
# ---------------------------------------------------------------------------

resource "libvirt_cloudinit_disk" "node" {
  for_each = local.nodes

  name = "${var.cluster_name}-${each.key}-cloudinit.iso"
  pool = libvirt_pool.vms.name

  meta_data = format("instance-id: %s\nlocal-hostname: %s\n", each.key, each.key)

  user_data = format("#cloud-config\n%s\n", yamlencode({
    hostname         = each.key
    fqdn             = "${each.key}.${var.domain}"
    manage_etc_hosts = true
    ssh_pwauth       = false

    users = [
      {
        name                = var.admin_user
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        lock_passwd         = true
        ssh_authorized_keys = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
      }
    ]
  }))
}

# ---------------------------------------------------------------------------
# Node disks (backing files of the golden image)
# ---------------------------------------------------------------------------

resource "libvirt_volume" "node" {
  for_each = local.nodes

  name           = "${var.cluster_name}-${each.key}.qcow2"
  pool           = libvirt_pool.vms.name
  base_volume_id = libvirt_volume.base.id
  format         = "qcow2"
}

# ---------------------------------------------------------------------------
# Domains (VMs) — 1 master + 2 workers
# ---------------------------------------------------------------------------

resource "libvirt_domain" "node" {
  for_each = local.nodes

  name       = "${var.cluster_name}-${each.key}"
  memory     = each.value.memory # MiB
  vcpu       = each.value.vcpu
  cloudinit  = libvirt_cloudinit_disk.node[each.key].id
  qemu_agent = true # agent is baked into the image; speeds up IP detection

  disk {
    volume_id = libvirt_volume.node[each.key].id
  }

  network_interface {
    network_name   = var.network_name
    wait_for_lease = true # wait for the DHCP lease so the IP shows up in outputs
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "vnc"
  }
}
