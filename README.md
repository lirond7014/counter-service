# Counter Service — FastAPI + React on EKS (GitOps/Argo CD, Helm, Terraform, Prometheus/Grafana)

A production-grade “counter” application consisting of:
- **Backend:** FastAPI (Python) with PostgreSQL persistence
- **Frontend:** React UI
- **Infra:** AWS supporting infrastructure managed with Terraform (EKS cluster is pre-provisioned in this AWS account)
- **Deployment:** Kubernetes via **Helm**, reconciled by **Argo CD (GitOps)**
- **Monitoring:** **Prometheus + Grafana** (ServiceMonitor provided)

> AWS account / permissions note (important):
> - In this AWS account, the **EKS cluster is pre-provisioned** and this repo **does not create the cluster**.
> - Terraform in this repository manages **supporting infrastructure** (RDS, ECR, security groups/rules, VPC endpoints, EKS addon IRSA where permitted).
> - Argo CD deploys the workloads from this repo using Helm.

---

## Quick links & how to access everything (dynamic / works even when names change)

The external URLs (ALB hostnames, etc.) can change. The most reliable approach is:
- use `kubectl` to **discover** the correct Service/Ingress names
- use `kubectl port-forward` to access UIs locally (always works when the Service is ClusterIP)

> Prereqs:
> - `kubectl` configured to the cluster (e.g. `aws eks update-kubeconfig ...`)
> - you can reach the Kubernetes API server from your machine
> - namespaces exist: `argocd`, `monitoring`, `counter-service`

### Git repository
- GitHub repo: https://github.com/lirond7014/counter-service
- Argo CD Application: `argo-service.yaml`
- Helm chart: `charts/counter-service`
- Terraform: `infrastructure/`
- Monitoring manifests: `monitoring/`

---

## Argo CD (UI)

In this cluster, Argo CD is **NOT** exposed publicly:
- `kubectl -n argocd get ingress` → **No resources found**
- `argocd-server` Service is `ClusterIP` (internal only)

### Private/local access via port-forward (current setup)
1) Confirm Argo CD server Service exists:
```bash
kubectl -n argocd get svc argocd-server -o wide
```

2) Port-forward Argo CD server HTTPS to your machine:
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

3) Open:
- https://localhost:8080

> Browser TLS note: the Argo CD server uses a self-signed certificate by default. Your browser may show a warning; proceed to the site.

### Login
Username:
- `admin`

Initial password (standard install):
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### Argo CD CLI (optional)
```bash
argocd login localhost:8080 --insecure
argocd app get counter-service
argocd app sync counter-service
argocd app history counter-service



---

## Grafana (UI)

> In this cluster Grafana is deployed by kube-prometheus-stack.
> - Service: `kube-prometheus-stack-grafana` (ClusterIP, port 80)
> - Ingress: `grafana` (ALB)

### Public access via Ingress (current setup)
1) Discover the Grafana Ingress and ALB hostname:
```bash
kubectl -n monitoring get ingress
```

2) Open the Ingress `ADDRESS` in your browser.

**Last known Grafana ALB hostname (as of 2026-03-14):**
- `http://k8s-monitori-grafana-476e1ea527-1271724809.eu-west-2.elb.amazonaws.com`

> This hostname can change if the Ingress/ALB is recreated. Always re-check with `kubectl -n monitoring get ingress`.

### Private/local access via port-forward (works regardless of ALB)
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open:
- http://localhost:3000

Credentials (kube-prometheus-stack default):
- Username: `admin`
- Password:
```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

---

## Prometheus (UI)

> In this cluster, Prometheus Service name is `kube-prometheus-stack-prometheus` in namespace `monitoring`.

### Private/local access via port-forward
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open:
- http://localhost:9090

### Public access (if exposed)
Check:
```bash
kubectl -n monitoring get ingress
kubectl -n monitoring get svc kube-prometheus-stack-prometheus -o wide
```

---

## Alertmanager (UI) (optional)

> In this cluster, Alertmanager Service name is `kube-prometheus-stack-alertmanager` in namespace `monitoring`.

### Private/local access via port-forward
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

Open:
- http://localhost:9093

### Public access (if exposed)
Check:
```bash
kubectl -n monitoring get ingress
kubectl -n monitoring get svc kube-prometheus-stack-alertmanager -o wide
```

---

## Counter Service (Frontend + Backend)

There are two ways to access the application:

### Option A — via Ingress (recommended when configured)
1) List ingresses:
```bash
kubectl -n counter-service get ingress
```

2) Open the `HOSTS` or `ADDRESS` shown.

### Option B — via port-forward (always works if Service exists)
1) List services:
```bash
kubectl -n counter-service get svc
```

2) Port-forward the frontend service:
```bash
kubectl -n counter-service port-forward svc/<FRONTEND_SERVICE_NAME> 3000:80
```

Open:
- http://localhost:3000

3) Port-forward the backend service:
```bash
kubectl -n counter-service port-forward svc/<BACKEND_SERVICE_NAME> 8000:80
```

Open:
- http://localhost:8000

Quick API checks:
```bash
curl -sS http://localhost:8000/health
curl -sS http://localhost:8000/
curl -sS -X POST http://localhost:8000/
curl -sS -X POST http://localhost:8000/reset
curl -sS http://localhost:8000/metrics | head
```

---

## GitOps (Argo CD)

Argo CD Application manifest:
- File: `argo-service.yaml`

It defines:
- App name: `counter-service`
- Argo namespace: `argocd`
- Destination namespace: `counter-service`
- Repo: `https://github.com/lirond7014/counter-service.git`
- Revision: `main`
- Helm chart path: `charts/counter-service`
- Release name: `counter-service`
- Sync policy: automated with `prune: true` and `selfHeal: true`
- Sync option: `CreateNamespace=true`

Apply:
```bash
kubectl apply -f argo-service.yaml
```

---

## Monitoring (Prometheus + Grafana)

ServiceMonitor:
- `monitoring/servicemonitor-counter-backend.yml`

Apply:
```bash
kubectl apply -f monitoring/servicemonitor-counter-backend.yml
```

---

## Infrastructure as Code (Terraform)

Terraform lives in:
- `infrastructure/`

Safe workflow:
```bash
cd infrastructure
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

- `plan` is read-only.
- `apply` changes AWS resources and requires appropriate permissions/change approval.