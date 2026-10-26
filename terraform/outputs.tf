output "master_ips" {
  description = "DHCP IPs of the master VMs (for the [master] group in the Ansible inventory)."
  value = [
    for name, dom in libvirt_domain.node :
    dom.network_interface[0].addresseses[0]
    if local.nodes[name].role == "master"
  ]
}

output "worker_ips" {
  description = "DHCP IPs of the worker VMs (for the [workers] group in the Ansible inventory)."
  value = [
    for name, dom in libvirt_domain.node :
    dom.network_interface[0].addresseses[0]
    if local.nodes[name].role == "worker"
  ]
}

output "all_nodes" {
  description = "Map of hostname -> IP for all nodes."
  value = {
    for name, dom in libvirt_domain.node :
    name => dom.network_interface[0].addresseses[0]
  }
}
