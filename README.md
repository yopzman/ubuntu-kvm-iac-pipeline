# ubuntu-kvm-iac-pipeline

End-to-end infrastructure automation pipeline for Ubuntu KVM: a golden image built with **Packer**, 3 VMs (1 master + 2 workers) provisioned with **Terraform** (the `dmacvicar/libvirt` provider), and configuration management with **Ansible**.

Run all commands below on an **Ubuntu host with KVM/libvirt enabled** (not on Windows/macOS).

## Architecture

| Stage | Tool | Output |
|---|---|---|
| 1. Golden image | Packer (QEMU/KVM + autoinstall) | `packer/output-qemu/ubuntu-noble-kvm.qcow2` |
| 2. VM provisioning | Terraform `dmacvicar/libvirt` | 1 master + 2 workers (cloud-init: hostname, user, SSH key) |
| 3. Configuration management | Ansible | Hardening, swap off, sysctl, container prerequisites (containerd) |

## Repository layout

```
├── packer/
│   ├── ubuntu.pkr.hcl        # QEMU builder + autoinstall served over HTTP
│   └── http/
│       ├── user-data         # autoinstall (user, partitioning, packages)
│       └── meta-data
├── terraform/
│   ├── providers.tf          # dmacvicar/libvirt provider
│   ├── variables.tf          # pool, network, master/worker specs
│   ├── main.tf               # cloud-init, backing volumes, VM domains
│   └── outputs.tf            # master & worker IPs (DHCP)
└── ansible/
    ├── ansible.cfg
    ├── inventory/hosts.ini   # filled in from `terraform output`
    ├── site.yml
    └── roles/
        ├── common/           # base packages, timezone, hostname
        ├── hardening/        # SSH, UFW, unattended-upgrades, remove packer user
        ├── swap_off/         # swapoff + comment out fstab entries
        ├── kernel_params/    # overlay/br_netfilter + container sysctls
        └── container_prereq/ # containerd + SystemdCgroup
```

## Host prerequisites

```bash
# KVM/libvirt
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst
sudo usermod -aG libvirt,kvm "$USER"   # log out and back in

# Tooling (one way to install them)
# Packer >= 1.9    : https://developer.hashicorp.com/packer/downloads
# Terraform >= 1.5 : https://developer.hashicorp.com/terraform/downloads
# Ansible >= 2.15  : pipx install ansible-core

# SSH keypair for VM access (default path used by this pipeline)
ssh-keygen -t ed25519
```

> If the Terraform provider fails to load, also run `sudo apt install libvirt-dev`.

## 1. Build the golden image with Packer

```bash
cd packer
packer init .
packer build .
# Result: output-qemu/ubuntu-noble-kvm.qcow2 (+ packer-manifest.json)
```

The image contains Ubuntu Server 24.04 (Noble), qemu-guest-agent, python3, and a temporary `packer` user (removed during the hardening stage).

## 2. Provision 3 VMs with Terraform

```bash
cd ../terraform
terraform init
terraform apply
```

Each VM gets a cloud-init disk (hostname `master-1` / `worker-1` / `worker-2`, user `ubuntu` + your SSH key, password login disabled) and a qcow2 disk backed by the golden image. VMs use the libvirt `default` network (DHCP, `192.168.122.0/24`).

```bash
terraform output master_ips
terraform output worker_ips
```

## 3. Fill in the Ansible inventory

Copy the IPs from the Terraform output into `ansible/inventory/hosts.ini`:

```ini
[master]
master-1 ansible_host=192.168.122.50

[workers]
worker-1 ansible_host=192.168.122.51
worker-2 ansible_host=192.168.122.52
```

## 4. Configure the nodes with Ansible

```bash
cd ../ansible
ansible all -m ping            # wait ±1 minute after apply for cloud-init to finish
ansible-playbook site.yml
```

What the playbook does:

- **common** — apt update/upgrade, base packages, timezone (`Asia/Jakarta`, change it in `roles/common/defaults/main.yml`), hostname, qemu-guest-agent.
- **hardening** — SSH drop-in (no root login, no password auth), UFW (OpenSSH only), unattended-upgrades, removal of the `packer` builder user.
- **swap_off** — `swapoff -a` + comment out swap entries in `/etc/fstab` (Kubernetes prerequisite).
- **kernel_params** — `overlay` & `br_netfilter` modules + sysctls (`ip_forward`, `bridge-nf-call-iptables`, etc.).
- **container_prereq** — install containerd, enable `SystemdCgroup`, set the pause sandbox image.

## Notes

- **Make sure SSH key access works before running the playbook** — the hardening role disables SSH password login.
- IPs are assigned via DHCP; for stable leases, add reservations to the libvirt network or switch to static IPs via cloud-init `network_config`.
- Bump the ISO point release by overriding the Packer variable: `packer build -var "iso_url=...ubuntu-24.04.X-live-server-amd64.iso" .`
- Teardown: `terraform -chdir=terraform destroy`, then `virsh vol-delete --pool k8s-lab-vms k8s-lab-vms-base.qcow2` to remove the base volume as well.
