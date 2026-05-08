# Homelab Kubernetes Platform

A fully automated, production-inspired homelab that provisions virtual machines, bootstraps a Kubernetes cluster, and deploys containerized applications using GitOps. This project demonstrates end-to-end DevOps practices across three distinct layers: Infrastructure as Code, Configuration Management, and Cloud-Native GitOps.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Developer Machine                     │
│   git push  ──►  GitHub Repository                      │
└─────────────────────┬───────────────────────────────────┘
                      │ Argo CD polls / webhook
                      ▼
┌─────────────────────────────────────────────────────────┐
│                 Proxmox VE Host                          │
│                                                         │
│  ┌──────────────┐   ┌────────────┐   ┌──────────────┐  │
│  │  k8s-master  │   │ k8s-worker1│   │ k8s-worker2  │  │
│  │ 192.168.88.210│  │192.168.88.211│ │192.168.88.212│  │
│  │   4GB RAM    │   │   2GB RAM  │   │   2GB RAM    │  │
│  └──────┬───────┘   └────────────┘   └──────────────┘  │
│         │  Kubernetes (kubeadm) + Flannel CNI            │
│         │  MetalLB (L2) + NGINX Ingress                  │
│         │  Argo CD (GitOps controller)                   │
└─────────────────────────────────────────────────────────┘
```

**Layer 1 — Provisioning (Terraform):** Spins up VMs on Proxmox VE using Cloud-Init templates with static IP assignment.

**Layer 2 — Configuration (Ansible):** Hardens the OS, installs the container runtime, bootstraps the Kubernetes cluster, and performs a one-time Argo CD installation.

**Layer 3 — GitOps (Argo CD):** Owns all post-bootstrap cluster state. Watches this Git repository and automatically reconciles any drift between Git and the live cluster.

---

## Tech Stack

| Category | Tool |
|---|---|
| Virtualization | Proxmox VE |
| IaC | Terraform |
| Configuration Management | Ansible |
| Orchestration | Kubernetes (kubeadm) |
| Container Runtime | containerd (systemd cgroup) |
| Networking | Flannel CNI, MetalLB (Layer 2) |
| Ingress | NGINX Ingress Controller |
| GitOps | Argo CD |
| Applications | Spring Boot (Java), PostgreSQL, Redis |

---

## Repository Structure

```
.
├── terraform/
│   └── proxmox/         # VM provisioning (Proxmox provider)
│       ├── main.tf
│       ├── variables.tf
│       └── providers.tf
│
├── ansible/             # Cluster bootstrap & Argo CD setup
│   ├── bootstrap-cluster.yml   # OS hardening, containerd, kubeadm
│   ├── deploy-all-apps.yml     # MetalLB, Ingress, Argo CD apps
│   ├── inventory.ini
│   ├── group_vars/
│   └── roles/
│       ├── common/      # OS hardening, dependencies
│       ├── master/      # kubeadm init, CNI setup
│       ├── workers/     # kubeadm join
│       └── argocd/      # Argo CD installation
│
└── k8s/                 # GitOps source of truth (watched by Argo CD)
    ├── apps/
    │   └── blog/        # Spring Boot blog application
    │       ├── blog-deployment.yml
    │       ├── blog-service.yml
    │       └── ingress.yml
    ├── infra/           # Cluster infrastructure config
    │   ├── metallb-pool.yml
    │   └── proxy-headers.yml
    └── argocd/          # Argo CD Application manifests
        ├── blog-app.yaml
        └── infra-app.yaml
```

---

## GitOps Workflow

This project implements GitOps principles using Argo CD. **Git is the single source of truth** — the cluster state always converges to what is defined in the `k8s/` directory.

```
git push
   │
   ▼
Argo CD detects diff (polls every ~3 min)
   │
   ├── k8s/apps/blog/*  ──► blog-app   (Deployment, Service, Ingress)
   └── k8s/infra/*      ──► infra-app  (MetalLB pool, proxy headers)
```

Both Argo CD Applications are configured with:

```yaml
syncPolicy:
  automated:
    prune: true      # removes resources deleted from Git
    selfHeal: true   # reverts manual kubectl changes automatically
```

**Day-to-day workflow — no Ansible, no kubectl needed:**

1. Update a manifest in `k8s/` (e.g. bump image tag, change replica count)
2. `git push`
3. Argo CD auto-syncs within 3 minutes

**Rolling updates with zero downtime** are configured on the blog deployment:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

Combined with a `readinessProbe`, this ensures the old pod stays alive and serving traffic until the new pod passes its health check.

---

## Getting Started

### Prerequisites

- Proxmox VE host with a Cloud-Init VM template
- Ansible installed locally with the `kubernetes.core` collection:
  ```bash
  ansible-galaxy collection install kubernetes.core
  ```
- Terraform installed locally
- `kubeconfig` accessible on your local machine after cluster bootstrap

### Step 1 — Provision VMs

```bash
cd terraform/proxmox
terraform init
terraform apply
```

This creates 3 VMs (1 master, 2 workers) with static IPs on your Proxmox host.

### Step 2 — Bootstrap the Cluster

```bash
cd ansible
ansible-playbook -i inventory.ini bootstrap-cluster.yml
```

Installs containerd, kubeadm, initializes the control plane, joins workers, and deploys Flannel CNI.

### Step 3 — Deploy Argo CD & Applications

```bash
ansible-playbook -i inventory.ini deploy-all-apps.yml
```

This single command:
- Installs Argo CD
- Installs MetalLB and assigns a LoadBalancer IP pool
- Installs NGINX Ingress Controller
- Applies the Argo CD Application manifests (`blog-app` and `infra-app`)

After this step, **Ansible's job is done**. Argo CD takes over all future deployments.

### Step 4 — Access Argo CD UI

```bash
# Get the LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Get the initial admin password (also printed by the playbook)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

---

## Nodes

| Node | Role | IP | RAM |
|---|---|---|---|
| k8s-master | Control Plane | 192.168.88.210 | 4GB |
| k8s-worker1 | Worker | 192.168.88.211 | 2GB |
| k8s-worker2 | Worker | 192.168.88.212 | 2GB |

---

## Key Design Decisions

**Ansible bootstraps once, Git owns everything after.** Ansible is intentionally scoped to cluster initialization. It applies the Argo CD Application manifests once — from that point on, all changes go through Git.

**No files are copied to the master node.** All `kubernetes.core.k8s` tasks in Ansible read manifests locally from the controller using `lookup('file', ...)` or `lookup('template', ...)`, keeping the master node stateless with respect to configuration files.

**Multi-document YAML manifests** (e.g. `metallb-pool.yml`) are applied using `from_yaml_all` to handle multiple `---` separated resources in a single file.

**`terraform.tfstate` is excluded from Git** — it may contain sensitive infrastructure details and should be stored securely (e.g. Terraform Cloud, S3 backend) in a real environment.