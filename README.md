# ubuntu-kvm-iac-pipeline

Pipeline otomasi infrastruktur lengkap untuk Ubuntu KVM: golden image dibangun dengan **Packer**, 3 VM (1 master + 2 worker) diprovision dengan **Terraform** (provider `dmacvicar/libvirt`), lalu dikonfigurasi dengan **Ansible**.

Semua perintah di bawah dijalankan di **host Ubuntu dengan KVM/libvirt aktif** (bukan di Windows/macOS).

## Arsitektur

| Tahap | Tool | Output |
|---|---|---|
| 1. Golden image | Packer (QEMU/KVM + autoinstall) | `packer/output-qemu/ubuntu-noble-kvm.qcow2` |
| 2. Provisioning VM | Terraform `dmacvicar/libvirt` | 1 master + 2 worker (cloud-init: hostname, user, SSH key) |
| 3. Config management | Ansible | Hardening, swap off, sysctl, prasyarat container (containerd) |

## Struktur direktori

```
├── packer/
│   ├── ubuntu.pkr.hcl        # QEMU builder + autoinstall via HTTP
│   └── http/
│       ├── user-data         # autoinstall (user, partisi, paket)
│       └── meta-data
├── terraform/
│   ├── providers.tf          # provider dmacvicar/libvirt
│   ├── variables.tf          # pool, jaringan, spesifikasi master/worker
│   ├── main.tf               # cloud-init, volume backing, domain VM
│   └── outputs.tf            # IP master & worker (DHCP)
└── ansible/
    ├── ansible.cfg
    ├── inventory/hosts.ini   # diisi IP dari `terraform output`
    ├── site.yml
    └── roles/
        ├── common/           # paket dasar, timezone, hostname
        ├── hardening/        # SSH, UFW, unattended-upgrades, hapus user packer
        ├── swap_off/         # swapoff + komentar fstab
        ├── kernel_params/    # overlay/br_netfilter + sysctl container
        └── container_prereq/ # containerd + SystemdCgroup
```

## Prasyarat host

```bash
# KVM/libvirt
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst
sudo usermod -aG libvirt,kvm "$USER"   # logout & login ulang

# Tooling (salah satu cara instalasi)
# Packer >= 1.9  : https://developer.hashicorp.com/packer/downloads
# Terraform >= 1.5 : https://developer.hashicorp.com/terraform/downloads
# Ansible >= 2.15  : pipx install ansible-core

# SSH keypair untuk akses VM (default path yang dipakai pipeline)
ssh-keygen -t ed25519
```

> Jika plugin Terraform gagal dimuat, install juga `sudo apt install libvirt-dev`.

## 1. Build golden image dengan Packer

```bash
cd packer
packer init .
packer build .
# Hasil: output-qemu/ubuntu-noble-kvm.qcow2 (+ packer-manifest.json)
```

Image berisi Ubuntu Server 24.04 (Noble), qemu-guest-agent, python3, user sementara `packer` (dihapus di tahap hardening).

## 2. Provisioning 3 VM dengan Terraform

```bash
cd ../terraform
terraform init
terraform apply
```

Setiap VM mendapat cloud-init disk (hostname `master-1` / `worker-1` / `worker-2`, user `ubuntu` + SSH key Anda, password login dinonaktifkan) dan disk qcow2 dengan backing file ke golden image. VM memakai network libvirt `default` (DHCP `192.168.122.0/24`).

```bash
terraform output master_ips
terraform output worker_ips
```

## 3. Isi IP ke inventory Ansible

Salin IP dari output Terraform ke `ansible/inventory/hosts.ini`:

```ini
[master]
master-1 ansible_host=192.168.122.50

[workers]
worker-1 ansible_host=192.168.122.51
worker-2 ansible_host=192.168.122.52
```

## 4. Konfigurasi node dengan Ansible

```bash
cd ../ansible
ansible all -m ping            # tunggu ±1 menit setelah apply agar cloud-init selesai
ansible-playbook site.yml
```

Yang dilakukan playbook:

- **common** — update/upgrade apt, paket dasar, timezone (`Asia/Jakarta`, ubah di `roles/common/defaults/main.yml`), hostname, qemu-guest-agent.
- **hardening** — drop-in SSH (tanpa root login/password), UFW (hanya OpenSSH), unattended-upgrades, hapus user builder `packer`.
- **swap_off** — `swapoff -a` + komentar entri swap di `/etc/fstab` (prasyarat Kubernetes).
- **kernel_params** — modul `overlay` & `br_netfilter` + sysctl (`ip_forward`, `bridge-nf-call-iptables`, dsb.).
- **container_prereq** — install containerd, aktifkan `SystemdCgroup`, set sandbox image pause.

## Catatan

- **Pastikan SSH key bisa dipakai sebelum playbook jalan** — role hardening mematikan login password SSH.
- IP bersifat DHCP; untuk lease stabil, tambahkan reservation di network libvirt atau konversi ke IP statis via cloud-init `network_config`.
- Naikkan point release ISO dengan override variabel Packer: `packer build -var "iso_url=...ubuntu-24.04.X-live-server-amd64.iso" .`
- Teardown: `terraform -chdir=terraform destroy`, lalu `virsh vol-delete --pool k8s-lab-vms k8s-lab-vms-base.qcow2` bila ingin menghapus base volume.
