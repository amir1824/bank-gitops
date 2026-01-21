# Mizrahi Bank - GitOps Repository

[![OpenShift](https://img.shields.io/badge/Platform-OpenShift-red?logo=redhat)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-orange?logo=argo)](https://argoproj.github.io/cd/)
[![Kafka](https://img.shields.io/badge/Streaming-Apache%20Kafka-black?logo=apachekafka)](https://kafka.apache.org/)

Complete GitOps repository for Mizrahi Bank's banking platform, following the **App-of-Apps** pattern with ArgoCD on Red Hat OpenShift.

## 📁 Repository Structure

```
mizrahi-bank-gitops/
├── bootstrap/                      # ArgoCD App-of-Apps Entry Point
│   ├── Chart.yaml                 # Helm umbrella chart metadata
│   ├── values.yaml                # Global configuration & toggles
│   └── templates/
│       ├── infrastructure.yaml    # ArgoCD App → /components/infra
│       └── apps.yaml              # ArgoCD App → /components/apps
│
├── charts/                        # Local Helm Charts
│   └── mainframe-mock/            # Python-based legacy system mock
│       ├── Chart.yaml
│       ├── values.yaml            # Defaults: python:3.9, replicas: 1
│       └── templates/
│           ├── _helpers.tpl       # Helm template helpers
│           ├── deployment.yaml    # Non-root container config
│           ├── service.yaml       # ClusterIP service
│           ├── route.yaml         # OpenShift Route (TLS edge)
│           └── configmap.yaml     # Python HTTP server code
│
├── components/                    # Kubernetes Manifests Layer
│   ├── infra/                     # Infrastructure Components
│   │   ├── kafka.yaml             # Strimzi Kafka Cluster (v3.7.0)
│   │   └── redis.yaml             # Redis Deployment + Service
│   └── apps/                      # Application Layer
│       └── mainframe.yaml         # ArgoCD App → /charts/mainframe-mock
│
└── infrastructure/                # Legacy structure (to be migrated)
    └── kafka/
        └── kafka-cluster.yaml     # Original Kafka config
```

## 🚀 Quick Start

### Prerequisites

1. **Red Hat OpenShift Cluster** (4.12+)
2. **ArgoCD Installed** in `argocd` namespace
3. **Strimzi Kafka Operator** installed cluster-wide
4. **kubectl/oc CLI** configured

### Deploy the Stack

#### 1. Install the Root Application (App-of-Apps)

```bash
# Apply the bootstrap chart to ArgoCD
oc apply -k bootstrap/

# OR using Helm directly
helm template bootstrap ./bootstrap \
  --namespace argocd \
  | oc apply -f -
```

#### 2. Verify Deployment

```bash
# Check ArgoCD applications
oc get applications -n argocd

# Expected output:
# NAME                      SYNC STATUS   HEALTH STATUS
# mizrahi-infrastructure    Synced        Healthy
# mizrahi-applications      Synced        Healthy

# Check infrastructure components
oc get kafka,deployment,svc -n mizrahi-core

# Check mainframe mock service
oc get deployment,route -n mizrahi-core -l app.kubernetes.io/name=mainframe-mock
```

#### 3. Access Services

```bash
# Get mainframe-mock route URL
MAINFRAME_URL=$(oc get route mainframe-mock -n mizrahi-core -o jsonpath='{.spec.host}')

# Test the service
curl https://$MAINFRAME_URL/status

# Expected response:
# {
#   "status": "Legacy System Online",
#   "version": "1.0.0",
#   "uptime": "operational",
#   "timestamp": "2026-01-21T..."
# }
```

## 🏗️ Architecture

### App-of-Apps Pattern

```
┌─────────────────────────────────────────┐
│   ArgoCD Bootstrap (Root App)           │
│   Path: /bootstrap                      │
└────────────┬────────────────────────────┘
             │
    ┌────────┴─────────┐
    │                  │
    ▼                  ▼
┌──────────────┐  ┌──────────────┐
│Infrastructure│  │ Applications │
│  ArgoCD App  │  │  ArgoCD App  │
└──────┬───────┘  └──────┬───────┘
       │                 │
       ▼                 ▼
┌─────────────┐   ┌──────────────┐
│ Kafka (CRD) │   │ Mainframe    │
│ Redis (K8s) │   │ Mock (Helm)  │
└─────────────┘   └──────────────┘
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **GitOps** | ArgoCD | Continuous deployment & sync |
| **Streaming** | Kafka 3.7.0 (Strimzi) | Event streaming platform |
| **Cache** | Redis 7.2 | In-memory data store |
| **Legacy Mock** | Python 3.9 | Mainframe simulator |
| **Platform** | OpenShift 4.x | Enterprise Kubernetes |

## 📦 Components

### 1. Bootstrap Layer (`/bootstrap`)

The entry point for ArgoCD. This Helm chart creates two child ArgoCD Applications:

- **mizrahi-infrastructure**: Manages Kafka and Redis
- **mizrahi-applications**: Manages application workloads

**Configuration** (`values.yaml`):
```yaml
global:
  repoURL: https://github.com/amir1824/bank-gitops.git
  targetRevision: main

infrastructure:
  enabled: true      # Toggle infrastructure deployment
  kafka:
    enabled: true
  redis:
    enabled: true

apps:
  enabled: true      # Toggle applications deployment
  mainframeMock:
    enabled: true
```

### 2. Infrastructure Layer (`/components/infra`)

#### Kafka Cluster (`kafka.yaml`)
- **Operator**: Strimzi Kafka Operator
- **Version**: 3.7.0
- **Configuration**: Single-node cluster with ephemeral storage
- **Listeners**: 
  - Plain (9092) - Internal, no TLS
  - TLS (9093) - Internal, TLS enabled
- **Entity Operators**: Topic & User operators enabled

#### Redis (`redis.yaml`)
- **Image**: redis:7.2-alpine
- **Configuration**: Non-root deployment with AppendOnly file enabled
- **Resources**: 128Mi-256Mi memory, 100m-200m CPU
- **Storage**: EmptyDir (ephemeral) for dev

### 3. Application Layer (`/components/apps`)

#### Mainframe Mock (`mainframe.yaml`)
ArgoCD Application that deploys the `/charts/mainframe-mock` Helm chart.

**Features**:
- Python 3.9-based HTTP server
- OpenShift Route with TLS edge termination
- Non-root security context (OpenShift SCC compliant)
- Health & readiness probes
- Multiple endpoints:
  - `/health` - Health check
  - `/status` - Main status (returns "Legacy System Online")
  - `/account/{id}` - Mock account lookup
  - `/transaction` - Mock transaction processing

## 🔒 Security

### OpenShift Security Standards

All components follow OpenShift security best practices:

1. **Non-root Containers**
   ```yaml
   securityContext:
     runAsNonRoot: true
     allowPrivilegeEscalation: false
     capabilities:
       drop: [ALL]
   ```

2. **Route TLS Termination**
   ```yaml
   tls:
     termination: edge
     insecureEdgeTerminationPolicy: Redirect
   ```

3. **Resource Limits**
   - All workloads have CPU/memory requests and limits
   - Prevents resource exhaustion

4. **Security Context Constraints (SCC)**
   - Compatible with `restricted-v2` SCC
   - No privilege escalation required

## 🛠️ Configuration

### Enable/Disable Components

Edit `bootstrap/values.yaml`:

```yaml
# Disable Redis
infrastructure:
  redis:
    enabled: false

# Disable all applications
apps:
  enabled: false
```

Then sync the bootstrap app:
```bash
argocd app sync bootstrap
```

### Customize Mainframe Mock

Edit `components/apps/mainframe.yaml` → `spec.source.helm.values`:

```yaml
helm:
  values: |
    replicaCount: 3           # Scale to 3 replicas
    route:
      host: mainframe.apps.ocp.example.com
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
```

### Production Hardening

For production deployments:

1. **Kafka**: Change to persistent storage
   ```yaml
   storage:
     type: persistent-claim
     size: 100Gi
     class: gp3-csi
   ```

2. **Redis**: Use Redis Operator or StatefulSet with PVC
3. **Secrets**: Store passwords in Sealed Secrets or Vault
4. **Monitoring**: Add Prometheus ServiceMonitors
5. **Backup**: Implement Velero backup policies

## 📊 Monitoring & Operations

### ArgoCD UI

```bash
# Get ArgoCD admin password
oc get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d

# Access ArgoCD UI
oc get route argocd-server -n argocd -o jsonpath='{.spec.host}'
```

### Application Health

```bash
# Check application sync status
argocd app list

# View application details
argocd app get mizrahi-infrastructure

# Manual sync if needed
argocd app sync mizrahi-applications --prune
```

### Kafka Operations

```bash
# List Kafka clusters
oc get kafka -n mizrahi-core

# Describe Kafka cluster
oc describe kafka mizrahi-cluster -n mizrahi-core

# Access Kafka logs
oc logs -n mizrahi-core mizrahi-cluster-kafka-0 -c kafka
```

## 🔄 Development Workflow

### Making Changes

1. **Edit manifests** in Git
2. **Commit and push** to repository
3. **ArgoCD auto-syncs** (if enabled) or manual sync
4. **Verify deployment** via ArgoCD UI or CLI

### Testing Locally

```bash
# Render Helm templates
helm template mainframe-mock ./charts/mainframe-mock

# Validate Kubernetes manifests
oc apply --dry-run=client -f components/infra/

# Test Python server locally
python3 charts/mainframe-mock/templates/configmap.yaml
```

## 📚 API Reference

### Mainframe Mock Endpoints

| Endpoint | Method | Description | Response |
|----------|--------|-------------|----------|
| `/health` | GET | Health check | `{"status": "healthy"}` |
| `/status` | GET | Service status | `{"status": "Legacy System Online"}` |
| `/account/{id}` | GET | Account lookup | Account details JSON |
| `/transaction` | POST | Process transaction | Transaction result JSON |

### Example cURL Commands

```bash
# Health check
curl https://$MAINFRAME_URL/health

# Check status
curl https://$MAINFRAME_URL/status

# Account lookup
curl https://$MAINFRAME_URL/account/123456

# Submit transaction
curl -X POST https://$MAINFRAME_URL/transaction \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "ILS"}'
```

## 🤝 Contributing

### Directory Conventions

- `/bootstrap` - ArgoCD root applications only
- `/charts` - Local Helm charts (versioned)
- `/components/infra` - Infrastructure manifests (Kafka, Redis, databases)
- `/components/apps` - Application ArgoCD definitions

### Naming Conventions

- **Resources**: `<service-name>` (e.g., `redis`, `kafka`)
- **ArgoCD Apps**: `mizrahi-<layer>` (e.g., `mizrahi-infrastructure`)
- **Labels**: Include `component: infrastructure|application` and `managed-by: argocd`

## 🐛 Troubleshooting

### Application Not Syncing

```bash
# Check ArgoCD application status
argocd app get <app-name>

# Force refresh
argocd app sync <app-name> --force
```

### Kafka Pod Not Starting

```bash
# Check Strimzi operator logs
oc logs -n openshift-operators -l name=strimzi-cluster-operator

# Check Kafka pod events
oc describe pod mizrahi-cluster-kafka-0 -n mizrahi-core
```

### Mainframe Mock Route Not Accessible

```bash
# Verify route exists
oc get route mainframe-mock -n mizrahi-core

# Check pod logs
oc logs -n mizrahi-core -l app.kubernetes.io/name=mainframe-mock

# Test internal service
oc run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl http://mainframe-mock.mizrahi-core.svc:8080/health
```

## 📄 License

Internal use - Mizrahi Bank DevOps Team

## 📧 Support

For issues or questions, contact: devops@mizrahi.bank

---

**Built with ❤️ by Mizrahi Bank DevOps Team**
