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
```

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

---

## Notes on HA, scaling, persistence choices, and trade-offs

This section documents the design decisions required by the assignment: **HA**, **scaling**, **persistence**, and the main **trade-offs**.

### High availability (HA)

#### What we implemented
The service is designed to remain available during:
- pod crashes / restarts
- node drains / evictions (planned disruption)
- rolling deployments via Argo CD

We implemented:
- **Multiple replicas** for both frontend and backend Deployments
- A **PodDisruptionBudget (PDB)** to limit simultaneous voluntary disruptions
- Application health checks (liveness/readiness) so Kubernetes only routes traffic to ready pods

Verification commands:
```bash
kubectl -n counter-service get deploy,pods -o wide
kubectl -n counter-service get pdb
kubectl -n counter-service describe pdb
```

#### Trade-offs
- More replicas increase availability and allow rolling updates with minimal downtime, but cost more (CPU/memory).
- PDBs protect availability during voluntary disruptions, but can slow down cluster autoscaler/Karpenter consolidation and node rotations if too strict.

> Note on restarts that “look like redeployments”:
> In EKS environments with node autoscaling/consolidation, pods may be evicted and rescheduled even without a Git change. This is expected behavior and should be handled by replicas + PDBs.

---

### Scaling (replicas + HPA)

#### What we implemented
We implemented **Horizontal Pod Autoscalers (HPAs)** for **both the backend and the frontend**.

Verification commands:
```bash
kubectl -n counter-service get hpa
kubectl -n counter-service describe hpa <BACKEND_HPA_NAME>
kubectl -n counter-service describe hpa <FRONTEND_HPA_NAME>
kubectl -n counter-service top pods
kubectl -n counter-service top nodes
```

#### How scaling works (practically)
- The HPA increases/decreases replicas based on observed load (commonly CPU utilization).
- Replicas allow the service to survive single-pod or single-node failures and also absorb traffic spikes.

#### Trade-offs
- CPU-based HPA is simple but not always perfectly correlated to HTTP request rate/latency.
- Scaling the backend increases concurrent DB usage; you must ensure DB connection pooling is sized safely to avoid exhausting DB connections.
- Frontend scaling is usually easy (stateless), but if the frontend is served as static assets behind an Ingress/ALB, you may not need high replica counts unless you serve a lot of traffic.

---

### Persistence choices for the counter (what we chose + alternatives)

#### Chosen approach: PostgreSQL (RDS)
The counter value is stored in PostgreSQL (RDS). This makes the counter survive:
- backend pod restarts
- node replacements
- rolling deployments
- multiple backend replicas

Why this choice:
- It supports HA cleanly because backend pods remain stateless.
- It provides durability and operational features (backups, snapshots, monitoring) in a managed AWS service.

Trade-offs:
- Adds network dependency and some latency vs an in-memory counter
- Requires credential management (Kubernetes Secret / external secret manager)
- Requires careful DB connection management under scale

#### Alternative 1: Local file + PVC
Store counter in a file on a PersistentVolumeClaim.
- Pros: simple; no external DB required.
- Cons / trade-offs:
  - EBS-backed PVCs are typically **ReadWriteOnce** (single writer), which complicates running multiple backend replicas.
  - Failover can be slower, and you can accidentally create “multiple counters” if replicas don’t share storage correctly.

#### Alternative 2: Redis / DynamoDB
- Redis (ElastiCache) can use atomic operations (INCR) and is fast.
- DynamoDB is highly available and scales well for counters.
Trade-offs:
- Additional AWS service(s) and IAM/security/ops overhead.
- Requires designing idempotency/atomic increment behavior carefully.

---

### Storage encryption note (AWS requirement)
The assignment requires encrypted storage.
- RDS storage should be encrypted (KMS).
- If PVCs/EBS volumes are used, the StorageClass should provision encrypted EBS volumes.

---

### Rollbacks and delivery strategy (GitOps)
Because delivery is GitOps:
- Roll forward by committing new image tags in Helm values.
- Roll back by reverting the commit (or setting image tags back) and letting Argo CD sync.

Best practice:
- Use immutable image tags (commit SHA tags) so rollbacks are deterministic.

---

### Observability notes (logs/metrics/traces)
- **Metrics:** backend exposes Prometheus metrics; ServiceMonitor is included.
- **Logs:** application logs should be structured (JSON is recommended). Viewing logs in Grafana typically requires a log backend such as **Loki** (Grafana does not store logs itself).
- **Tracing (bonus):** OpenTelemetry libraries are included; a tracing backend (e.g., Jaeger) is required to view traces.