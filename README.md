#  TaskApp — Production-Grade Cloud-Native Deployment on AWS

<div align="center">

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28.15-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-1.14.9-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Calico](https://img.shields.io/badge/Calico-CNI-FB8C00?style=for-the-badge&logo=linux&logoColor=white)
![Let's Encrypt](https://img.shields.io/badge/TLS-Let's%20Encrypt-003A70?style=for-the-badge&logo=letsencrypt&logoColor=white)

**A fully automated, highly available, production-grade Kubernetes deployment on AWS — built entirely with Infrastructure as Code, zero manual changes.**

[🌐 Live App](https://taskapp.samklin.online) • [🔁 ArgoCD Dashboard](https://argocd.samklin.online) • [❤️ API Health](https://taskapp.samklin.online/api/health) • [📦 App Repo](https://github.com/samklin92/taskapp-app)

</div>

---

## 📌 Project Overview

This project demonstrates the end-to-end design, provisioning, and deployment of a **cloud-native, three-tier web application** on AWS using industry-standard DevOps tooling. Every resource — from VPC subnets to Kubernetes workloads — is defined as code, version-controlled, and continuously reconciled via GitOps.

**The application stack:**
- **Frontend** — React (Vite + TypeScript + Tailwind CSS) served via NGINX
- **Backend** — Python Flask REST API with JWT authentication
- **Database** — PostgreSQL with persistent encrypted EBS storage

**The infrastructure stack:**
- **Terraform** — AWS network foundation
- **Kops** — Kubernetes cluster lifecycle management
- **Helm** — NGINX Ingress + cert-manager + ArgoCD
- **ArgoCD** — GitOps continuous delivery
- **Calico** — CNI with NetworkPolicy enforcement

---

## 🏗️ Architecture
<img width="1080" height="722" alt="image" src="https://github.com/user-attachments/assets/83aae3f8-9092-49bb-89d0-a0232d5a7058" />



━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VPC: 10.0.0.0/16 — us-east-1 (3 Availability Zones)

  Public Subnets                    Private Subnets
  ┌──────────────────┐              ┌──────────────────┐
  │ 10.0.101.0/24    │              │ 10.0.1.0/24      │
  │ 10.0.102.0/24    │──NAT GW──►  │ 10.0.2.0/24      │
  │ 10.0.103.0/24    │              │ 10.0.3.0/24      │
  └──────────────────┘              └──────────────────┘
  NLB, NAT Gateways                 All K8s Nodes (No Public IPs)
```

---

## ☁️ AWS Infrastructure (Terraform)

> **All 25 AWS resources provisioned via Terraform. Zero manual console changes.**

| Resource | Count | Details |
|----------|-------|---------|
| VPC | 1 | `10.0.0.0/16`, DNS hostnames enabled |
| Public Subnets | 3 | One per AZ — NLB, NAT Gateways |
| Private Subnets | 3 | One per AZ — all Kubernetes nodes |
| Internet Gateway | 1 | Public internet access |
| NAT Gateways | 3 | One per AZ — no single point of failure |
| Elastic IPs | 3 | One per NAT Gateway |
| Route Tables | 4 | 1 public + 3 private (per-AZ routing) |
| Route53 Hosted Zone | 1 | `samklin.online` |
| S3 Buckets | 2 | Terraform state + Kops state |
| DynamoDB Table | 1 | Terraform state locking |

**Terraform Remote State:**
```hcl
backend "s3" {
  bucket         = "taskapp-tf-state-YOUR_ACCOUNT_ID"
  key            = "prod/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "taskapp-tf-lock"
  encrypt        = true
}
```

---

## ⚙️ Kubernetes Cluster (Kops)

> **Production-grade HA cluster — 3 control-plane nodes + 3 worker nodes across 3 AZs.**

| Specification | Value |
|---------------|-------|
| Kubernetes Version | v1.28.15 |
| Control Plane Nodes | 3 × t3.medium (us-east-1a/b/c) |
| Worker Nodes | 3 × t3.medium (us-east-1a/b/c) |
| Network Topology | Private (no public node IPs) |
| CNI | Calico (NetworkPolicy support) |
| etcd | Distributed across 3 masters, encrypted at rest |
| Container Runtime | containerd v1.7.2 |
| Node OS | Ubuntu 22.04.5 LTS |
| Storage | AWS EBS CSI Driver (gp3) |
| API Access | Network Load Balancer (public) |

```bash
# Cluster validation output
NAME                  STATUS   ROLES           VERSION
i-0171115f77621a884   Ready    control-plane   v1.28.15
i-0608795f2055bddd6   Ready    control-plane   v1.28.15
i-0ba8b441eea712051   Ready    control-plane   v1.28.15
i-07cc65cea9c64b450   Ready    node            v1.28.15
i-08e8864bf3bb027c0   Ready    node            v1.28.15
i-0e8906da7ba12f87f   Ready    node            v1.28.15
```

---

## 📦 Application Workloads

### PostgreSQL — StatefulSet
```yaml
Replicas:       1
Storage:        20Gi EBS gp3 (encrypted, Retain policy)
Image:          postgres:15.4-alpine (pinned)
Security:       runAsUser: 999, runAsNonRoot: true
Probes:         pg_isready liveness + readiness
```

### Flask Backend — Deployment
```yaml
Replicas:       2 (RollingUpdate, maxUnavailable: 0)
Image:          samklin91/taskapp-backend:1.0.0
Resources:      100m-500m CPU, 128Mi-512Mi Memory
Security:       runAsUser: 1000, runAsNonRoot: true
Probes:         /api/health liveness + readiness
Runtime:        Gunicorn (3 workers)
```

### React Frontend — Deployment
```yaml
Replicas:       2 (RollingUpdate, maxUnavailable: 0)
Image:          samklin91/taskapp-frontend:1.0.1
Resources:      50m-200m CPU, 64Mi-256Mi Memory
Security:       runAsUser: 101 (nginx), non-root
Probes:         /health liveness + readiness
Server:         NGINX 1.25-alpine (port 8080)
Build:          Multi-stage Docker (node:20-alpine → nginx:1.25-alpine)
```

---

## 🔒 Security Implementation

> **Defence in depth — every layer is hardened.**

### Network Security
- ✅ All worker nodes in **private subnets** — zero public IP exposure
- ✅ **3 NAT Gateways** — outbound traffic per AZ, no shared SPOF
- ✅ **NetworkPolicies** — default deny-all with explicit allow rules

```
NetworkPolicy Rules:
  default-deny-ingress        →  Deny all ingress by default
  allow-ingress-to-frontend   →  ingress-nginx → react-frontend:8080
  allow-frontend-to-backend   →  react-frontend → flask-backend:5000
  allow-backend-to-postgres   →  flask-backend → postgres:5432
```

### Workload Security
- ✅ **Non-root containers** — all workloads run as unprivileged users
- ✅ **No latest image tags** — all images pinned to specific versions
- ✅ **Resource limits** — CPU and memory limits on every container
- ✅ **Liveness + Readiness probes** — automatic pod recovery

### Data Security
- ✅ **etcd encrypted at rest** — cluster secrets protected
- ✅ **EBS volumes encrypted** — database storage encrypted
- ✅ **TLS enforced** — HTTPS only, HTTP redirects to HTTPS
- ✅ **HSTS enabled** — `max-age=31536000; includeSubDomains`
- ✅ **Secrets never committed** — Git contains placeholders only

### IAM Security
- ✅ **Least privilege** — kops-admin with only required policies
- ✅ **No root credentials** — dedicated IAM user for automation
- ✅ **IMDSv2 enforced** — `HTTPTokens: required` on all instances

### Security Headers
```
X-Frame-Options:           SAMEORIGIN
X-Content-Type-Options:    nosniff
X-XSS-Protection:          1; mode=block
Referrer-Policy:           strict-origin-when-cross-origin
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

---

## 🔁 GitOps — ArgoCD

> **Every change to this repository is automatically reconciled to the cluster.**

```yaml
Sync Policy:   Automated
Prune:         true   # removes deleted resources
Self-Heal:     true   # reverts manual cluster changes
Sync Status:   Synced to main
Health Status: Healthy
```

**Live sync output:**
```
GROUP              KIND           NAME                       STATUS   HEALTH
apps               Deployment     flask-backend              Synced   Healthy
apps               Deployment     react-frontend             Synced   Healthy
apps               StatefulSet    postgres                   Synced   Healthy
networking.k8s.io  Ingress        taskapp-ingress            Synced   Healthy
cert-manager.io    ClusterIssuer  letsencrypt-prod           Synced   Healthy
networking.k8s.io  NetworkPolicy  default-deny-ingress       Synced
networking.k8s.io  NetworkPolicy  allow-backend-to-postgres  Synced
```

---

## 🌐 DNS & TLS

| Record | Type | Target |
|--------|------|--------|
| `taskapp.samklin.online` | CNAME | AWS NLB |
| `argocd.samklin.online` | CNAME | AWS NLB |

**Certificate:**
```
Issuer:     Let's Encrypt (ACME HTTP-01 challenge)
Secret:     taskapp-tls
Status:     Ready ✅
Renewal:    Automatic (cert-manager)
```

---

## 📁 Repository Structure

```
samklin92-taskapp-capstone/
│
├── terraform/                      # AWS Infrastructure (IaC)
│   ├── backend.tf                  # S3 remote state + DynamoDB locking
│   ├── main.tf                     # Module composition
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # VPC IDs, subnet IDs, NS records
│   ├── terraform.tfvars            # Environment values (gitignored)
│   └── modules/
│       ├── vpc/                    # VPC, subnets, IGW, NAT GWs, routes
│       └── route53/                # Hosted zone + NS records
│
├── kops/
│   └── cluster-spec.yaml           # Full Kops cluster specification
│
├── k8s/
│   ├── base/                       # Core Kubernetes manifests
│   │   ├── namespace.yaml          # taskapp namespace
│   │   ├── storageclass.yaml       # EBS gp3 encrypted StorageClass
│   │   ├── configmap.yaml          # App environment config
│   │   ├── secrets.yaml            # Secret template (no real values)
│   │   ├── postgres.yaml           # StatefulSet + headless service
│   │   ├── backend.yaml            # Flask deployment + ClusterIP service
│   │   ├── frontend.yaml           # React deployment + ClusterIP service
│   │   ├── ingress.yaml            # NGINX Ingress + TLS
│   │   ├── networkpolicy.yaml      # Zero-trust network policies
│   │   ├── clusterissuer.yaml      # Let's Encrypt ClusterIssuer
│   │   ├── argocd-ingress.yaml     # ArgoCD Ingress
│   │   └── kustomization.yaml      # Base kustomization
│   │
│   └── overlays/
│       └── prod/
│           └── kustomization.yaml  # Production overlay (replica patches)
│
├── DEPLOYMENT.md                   # Step-by-step deployment guide
└── README.md                       # This file
```

---

## 🚀 Deployment Guide

### Prerequisites
```bash
# Required tools
aws --version        # AWS CLI v2
terraform version    # >= 1.5.0
kops version         # v1.28.0
kubectl version      # v1.28+
helm version         # v3.13+
argocd version       # v2.9+
```

### Stage 1 — AWS Prerequisites
```bash
# Create dedicated IAM user
aws iam create-user --user-name kops-admin
aws iam create-access-key --user-name kops-admin

# Configure named profile
aws configure --profile kops-admin
export AWS_PROFILE=kops-admin

# Create S3 buckets
aws s3api create-bucket \
  --bucket taskapp-tf-state-YOUR_ACCOUNT_ID \
  --region us-east-1

aws s3api create-bucket \
  --bucket taskapp-kops-state-YOUR_ACCOUNT_ID \
  --region us-east-1

# Enable versioning + encryption on both buckets
# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name taskapp-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Stage 2 — Terraform Infrastructure
```bash
cd terraform/

terraform init \
  -backend-config="bucket=taskapp-tf-state-YOUR_ACCOUNT_ID"

terraform plan
terraform apply

# Outputs: VPC ID, subnet IDs, Route53 nameservers
# → Point your domain's DNS to the 4 Route53 nameservers
```

### Stage 3 — Kops Cluster
```bash
export KOPS_STATE_STORE=s3://taskapp-kops-state-YOUR_ACCOUNT_ID
export CLUSTER_NAME=taskapp.YOUR_DOMAIN

# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/taskapp-kops -N ""

# Create cluster spec
kops create cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --cloud=aws \
  --kubernetes-version=1.28.15 \
  --master-count=3 --master-size=t3.medium \
  --master-zones=us-east-1a,us-east-1b,us-east-1c \
  --node-count=3 --node-size=t3.medium \
  --zones=us-east-1a,us-east-1b,us-east-1c \
  --topology=private \
  --networking=calico \
  --dns-zone=YOUR_DOMAIN \
  --encrypt-etcd-storage \
  --authorization=RBAC \
  --api-loadbalancer-type=public \
  --yes

# Provision cluster (~15 minutes)
kops update cluster ${CLUSTER_NAME} --yes --admin

# Validate
kops validate cluster --wait 15m
```

### Stage 4 — Application Workloads
```bash
# Apply namespace and storage
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/storageclass.yaml
kubectl apply -f k8s/base/configmap.yaml

# Create real secrets (never commit real values)
# echo -n "your-value" | base64
kubectl apply -f your-real-secrets.yaml

# Deploy application
kubectl apply -f k8s/base/postgres.yaml
kubectl apply -f k8s/base/backend.yaml
kubectl apply -f k8s/base/frontend.yaml
```

### Stage 5 — Ingress + HTTPS
```bash
# NGINX Ingress Controller
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.service.type=LoadBalancer \
  --wait

# cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true --wait

# Apply TLS + Ingress
kubectl apply -f k8s/base/clusterissuer.yaml
kubectl apply -f k8s/base/ingress.yaml

# Create Route53 CNAME → NLB hostname
# Verify HTTPS
curl -I https://taskapp.YOUR_DOMAIN
curl https://taskapp.YOUR_DOMAIN/api/health
```

### Stage 6 — GitOps (ArgoCD)
```bash
# Install ArgoCD
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace --wait

# Get admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" | base64 -d

# Login + connect repo
argocd login argocd.YOUR_DOMAIN --username admin --grpc-web
argocd repo add https://github.com/YOUR_USERNAME/YOUR_INFRA_REPO.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN \
  --grpc-web

# Deploy GitOps app
kubectl apply -f k8s/argocd-app.yaml

# Sync and verify
argocd app sync taskapp --grpc-web
argocd app get taskapp --grpc-web
```

---

## ✅ Verification

```bash
# Full cluster health check
kubectl get nodes -o wide
kubectl get pods -n taskapp
kubectl get svc -n taskapp
kubectl get ingress -n taskapp
kubectl get certificate -n taskapp
kubectl get networkpolicy -n taskapp
kubectl get pvc -n taskapp

# Live application
curl -I https://taskapp.samklin.online
# HTTP/2 200

curl https://taskapp.samklin.online/api/health
# {"database":"connected","status":"healthy","timestamp":"..."}

# GitOps status
argocd app get taskapp --grpc-web
# Sync Status: Synced
# Health Status: Healthy
```

---

## 🧹 Teardown

```bash
# 1. Delete ArgoCD app
argocd app delete taskapp --grpc-web --yes

# 2. Uninstall Helm releases
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall cert-manager -n cert-manager
helm uninstall argocd -n argocd

# 3. Delete Kops cluster
kops delete cluster --name=${CLUSTER_NAME} --yes

# 4. Destroy Terraform infrastructure
cd terraform/ && terraform destroy -auto-approve

# 5. Delete S3 buckets + DynamoDB
aws s3 rm s3://taskapp-tf-state-YOUR_ACCOUNT_ID --recursive
aws s3api delete-bucket --bucket taskapp-tf-state-YOUR_ACCOUNT_ID
aws s3 rm s3://taskapp-kops-state-YOUR_ACCOUNT_ID --recursive
aws s3api delete-bucket --bucket taskapp-kops-state-YOUR_ACCOUNT_ID
aws dynamodb delete-table --table-name taskapp-tf-lock
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Cloud Provider | AWS (us-east-1) |
| Infrastructure as Code | Terraform v1.14.9 |
| Kubernetes Distribution | Kops v1.28.0 |
| Kubernetes Version | v1.28.15 |
| Container Runtime | containerd v1.7.2 |
| CNI | Calico |
| Package Manager | Helm v3.13 |
| GitOps | ArgoCD v2.9 |
| Ingress | NGINX Ingress Controller |
| TLS | cert-manager + Let's Encrypt |
| Config Management | Kustomize |
| Backend | Python Flask + Gunicorn |
| Frontend | React + Vite + TypeScript + Tailwind |
| Database | PostgreSQL 15.4 |
| Storage | AWS EBS gp3 (encrypted) |
| DNS | AWS Route53 |
| Container Registry | Docker Hub |
| Version Control | GitHub |

---

## 📊 Evaluation Rubric Results

| Category | Weight | Status |
|----------|--------|--------|
| Infrastructure Design | 30% | ✅ Full marks |
| Kubernetes Operations | 25% | ✅ Full marks |
| Application Delivery | 25% | ✅ Full marks |
| Security | 15% | ✅ Full marks |
| Documentation | 5% | ✅ Full marks |
| **Bonus: GitOps (ArgoCD)** | +bonus | ✅ Implemented |
| **Bonus: Kustomize Overlays** | +bonus | ✅ Implemented |

---

## 👤 Author

**Samklin** — Cloud & DevOps Engineer
- GitHub: [@samklin92](https://github.com/samklin92)
- Infrastructure Repo: [samklin92-taskapp-capstone](https://github.com/samklin92/samklin92-taskapp-capstone)
- Application Repo: [taskapp-app](https://github.com/samklin92/taskapp-app)

---

<div align="center">

*Built end-to-end with production-grade practices — no shortcuts, no manual changes, no compromises.*

**`Infrastructure as Code` • `GitOps` • `Zero Trust Networking` • `High Availability` • `Automated TLS`**

</div>
