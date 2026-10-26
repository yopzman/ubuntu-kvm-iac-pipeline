output "master_ips" {
  description = "IP DHCP VM master (untuk grup [master] di inventory Ansible)."
  value = [
    for name, dom in libvirt_domain.node :
    dom.network_interface[0].addresseses[0]
    if local.nodes[name].role == "master"
  ]
}

output "worker_ips" {
  description = "IP DHCP VM worker (untuk grup [workers] di inventory Ansible)."
  value = [
    for name, dom in libvirt_domain.node :
    dom.network_interface[0].addresseses[0]
    if local.nodes[name].role == "worker"
  ]
}

output "all_nodes" {
  description = "Peta hostname -> IP untuk semua node."
  value = {
    for name, dom in libvirt_domain.node :
    name => dom.network_interface[0].addresseses[0]
  }
}
