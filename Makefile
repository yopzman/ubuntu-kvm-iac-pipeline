# Single entry point for the ubuntu-kvm-iac-pipeline.
# Run on the Ubuntu KVM host. Typical flow:
#   make image -> make cluster -> make configure -> make k8s -> make verify

SHELL := /bin/bash
IMAGE := packer/output-qemu/ubuntu-noble-kvm.qcow2
SSH_PUB_KEY ?= $(HOME)/.ssh/id_ed25519.pub

.PHONY: help image cluster cluster-auto inventory configure k8s verify destroy lint

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

image: ## Build the golden image with Packer (incl. baked baseline roles)
	cd packer && packer init . && packer build .

cluster: ## Provision the VMs with Terraform (interactive approval)
	@test -f $(SSH_PUB_KEY) || (echo "SSH public key not found at $(SSH_PUB_KEY) - run ssh-keygen first"; exit 1)
	@test -f $(IMAGE) || (echo "Golden image not found at $(IMAGE) - run 'make image' first"; exit 1)
	cd terraform && terraform init && terraform apply

cluster-auto: ## Provision the VMs with Terraform (auto-approve; used by CI/e2e)
	@test -f $(SSH_PUB_KEY) || (echo "SSH public key not found at $(SSH_PUB_KEY) - run ssh-keygen first"; exit 1)
	@test -f $(IMAGE) || (echo "Golden image not found at $(IMAGE) - run 'make image' first"; exit 1)
	cd terraform && terraform init && terraform apply -auto-approve

inventory: ## Regenerate the Ansible inventory from Terraform state
	python3 scripts/generate-inventory.py

configure: inventory ## Apply the baseline Ansible roles (common, hardening, ...)
	cd ansible && ansible-playbook site.yml

k8s: ## Bootstrap the Kubernetes cluster (kubeadm + Flannel)
	cd ansible && ansible-playbook k8s.yml

verify: ## Run post-deployment checks (services + kubectl get nodes)
	cd ansible && ansible-playbook verify.yml

destroy: ## Destroy the VMs (golden image and pool contents are kept)
	cd terraform && terraform destroy

lint: ## Best-effort formatters/validators (terraform, packer, yamllint, ansible-lint)
	cd terraform && terraform fmt -check -recursive
	cd terraform && terraform init -backend=false -input=false >/dev/null && terraform validate
	cd packer && packer fmt -check .
	@if command -v yamllint >/dev/null; then yamllint .; else echo "yamllint not installed - skipping"; fi
	@if command -v ansible-lint >/dev/null; then cd ansible && ansible-lint; else echo "ansible-lint not installed - skipping"; fi
