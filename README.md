#  Bank - GitOps Repository

[![OpenShift](https://img.shields.io/badge/Platform-OpenShift-red?logo=redhat)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-orange?logo=argo)](https://argoproj.github.io/cd/)
[![Kafka](https://img.shields.io/badge/Streaming-Apache%20Kafka-black?logo=apachekafka)](https://kafka.apache.org/)
[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)

Professional GitOps repository for  Bank using ArgoCD's **App-of-Apps** pattern on Red Hat OpenShift.

---

## 📁 Repository Structure

```
bank-gitops/
├── bootstrap/                          # ⭐ GitOps Entry Point (START HERE)
│   ├── root-app.yaml                  # The ONE file to apply manually
│   ├── cluster-resources/             # OpenShift cluster-wide resources
│   │   └── consolelink.yaml          # ArgoCD console link
│   └── README.md                      # Detailed bootstrap guide
│
├── apps-chart/                         # 🎯 App-of-Apps Helm Chart
│   ├── Chart.yaml                     # Chart metadata v1.0.0
│   ├── values.yaml                    # Global config & feature toggles
│   └── templates/                     # ArgoCD Application generators
│       ├── _helpers.tpl               # Helm template helpers
│       ├── infra-kafka.yaml           # ArgoCD App → Kafka
│       ├── infra-redis.yaml           # ArgoCD App → Redis
│       ├── app-mainframe.yaml         # ArgoCD App → Mainframe Mock
│       └── app-account-service.yaml   # ArgoCD App → Account Service
│
├── charts/                            # 📦 Custom Application Helm Charts
│   ├── mainframe-mock/                # Python legacy system simulator
│   │   ├── Chart.yaml
│   │   ├── values.yaml                # python:3.9, user 1001 (non-root)
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml        # SCC-compliant (user 1001)
│   │       ├── service.yaml
│   │       ├── route.yaml             # OpenShift Route (TLS edge)
│   │       └── configmap.yaml         # Python HTTP server code
│   │
│   └── account-service/               # .NET Core 8.0 banking API
│       ├── Chart.yaml
│       ├── values.yaml                # dotnet:8.0, user 1001 (non-root)
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml        # SCC-compliant (user 1001)
│           ├── configmap.yaml         # App configuration
│           ├── service.yaml
│           ├── route.yaml             # OpenShift Route (TLS edge)
│           ├── pdb.yaml               # Pod Disruption Budget
│           └── hpa.yaml               # Horizontal Pod Autoscaler
│
└── components/                        # 🔧 Infrastructure Components
    └── infra/                         # Infrastructure manifests
        ├── kafka/                     # Apache Kafka (Strimzi)
        │   └── kafka.yaml             # Kafka CRD v3.7.0
        └── redis/                     # Redis Cache
            └── redis.yaml             # Redis Deployment + Service
```

---

## 🚀 Quick Start

### Prerequisites

1. **Red Hat OpenShift Cluster** (4.12+)
2. **ArgoCD Installed** in `argocd` namespace
3. **Strimzi Kafka Operator** (for Kafka)
4. **kubectl/oc CLI** configured

### One-Command Deployment

```bash
# Clone the repository
git clone https://github.com/amir1824/bank-gitops.git
cd bank-gitops

# Apply the root application (bootstraps everything)
oc apply -f bootstrap/root-app.yaml
```

**That's it!** ArgoCD will now manage the entire stack automatically.

### Verify Deployment

```bash
# Check ArgoCD applications
oc get applications -n argocd

# Expected output:
# NAME                      SYNC STATUS   HEALTH STATUS
# mizrahi-root              Synced        Healthy
# infra-kafka               Synced        Healthy
# infra-redis               Synced        Healthy
# app-mainframe-mock        Synced        Healthy
# app-account-service       Synced        Healthy

# Check deployed resources
oc get all -n mizrahi-core
```

### Access Services

```bash
# Get service URLs
oc get routes -n mizrahi-core

# Test mainframe-mock
MAINFRAME_URL=$(oc get route mainframe-mock -n mizrahi-core -o jsonpath='{.spec.host}')
curl https://$MAINFRAME_URL/status

# Test account-service
ACCOUNT_URL=$(oc get route account-service -n mizrahi-core -o jsonpath='{.spec.host}')
curl https://$ACCOUNT_URL/health
```

---

## 🏗️ Architecture

### App-of-Apps Pattern

```
┌─────────────────────────────────────┐
│  Bootstrap (root-app.yaml)          │
│  Applied ONCE manually              │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Apps-Chart (Helm)                  │
│  Generates ArgoCD Applications      │
└────────────┬────────────────────────┘
             │
      ┌──────┴──────────┐
      │                 │
      ▼                 ▼
┌──────────────┐  ┌──────────────┐
│Infrastructure│  │ Applications │
├──────────────┤  ├──────────────┤
│ • Kafka      │  │ • Mainframe  │
│ • Redis      │  │ • Account    │
└──────────────┘  └──────────────┘
```

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **GitOps** | ArgoCD | Latest | CD & Sync |
| **Platform** | OpenShift | 4.12+ | Container Platform |
| **Streaming** | Kafka (Strimzi) | 3.7.0 | Event Streaming |
| **Cache** | Redis | 7.2 | In-Memory Store |
| **Legacy Mock** | Python | 3.9 | Mainframe Simulator |
| **API Service** | .NET Core | 8.0 | Banking REST API |

---

## 🎯 Key Features

### ✅ OpenShift Native

- **Routes** instead of Ingress (with TLS edge termination)
- **SecurityContextConstraints (SCC)** compliant
- **Non-root containers** (user 1001)
- **HSTS headers** enabled
- **Resource limits** on all workloads

### ✅ Production Ready

- **Automated sync** with self-healing
- **Health checks** (liveness & readiness probes)
- **Pod Disruption Budgets** for high availability
- **Horizontal Pod Autoscaling** support
- **Sync waves** for ordered deployment
- **Proper finalizers** for cascading deletion

### ✅ GitOps Best Practices

- **Single source of truth** (Git repository)
- **Declarative configuration** (YAML manifests)
- **Version controlled** infrastructure
- **Rollback capability** via Git history
- **Environment separation** via values overrides

---

## 🔧 Configuration

### Enable/Disable Components

Edit `apps-chart/values.yaml` to toggle services:

```yaml
infrastructure:
  kafka:
    enabled: true    # Set to false to disable Kafka
  redis:
    enabled: false   # Disable Redis

applications:
  mainframeMock:
    enabled: true
  accountService:
    enabled: false   # Disable account service
```

Or override in `bootstrap/root-app.yaml`:

```yaml
helm:
  values: |
    infrastructure:
      kafka:
        enabled: false
```

### Environment-Specific Configuration

```yaml
# In apps-chart/values.yaml
global:
  environment: prod  # Change from 'dev' to 'prod'

# Production overrides are applied automatically
prod:
  infrastructure:
    kafka:
      replicas: 3    # Scale Kafka to 3 replicas
  applications:
    accountService:
      replicas: 3    # Scale account service
```

### Custom Domain

```yaml
global:
  domain: apps.prod.mizrahi.bank

applications:
  accountService:
    helm:
      values:
        route:
          host: api.prod.mizrahi.bank
```

---

## 📦 Components Details

### Infrastructure Layer

#### Kafka (Strimzi)
- **Purpose**: Event streaming platform
- **Configuration**: Single-node dev cluster
- **Listeners**: Plain (9092), TLS (9093)
- **Storage**: Ephemeral (change to PVC for production)
- **Entity Operators**: Topic & User management

#### Redis
- **Purpose**: Caching and session storage
- **Image**: redis:7.2-alpine
- **Security**: Non-root (user 1001)
- **Persistence**: EmptyDir (change to PVC for production)

### Application Layer

#### Mainframe Mock (Python)
- **Purpose**: Legacy mainframe system simulator
- **Language**: Python 3.9
- **Endpoints**:
  - `/health` - Health check
  - `/status` - Returns `{"status": "Legacy System Online"}`
  - `/account/{id}` - Mock account lookup
  - `/transaction` - Mock transaction processing
- **Security**: Runs as user 1001 (non-root)

#### Account Service (.NET)
- **Purpose**: Banking account management API
- **Framework**: .NET 8.0 (ASP.NET Core)
- **Features**:
  - RESTful API
  - Kafka integration for events
  - Redis caching
  - Database connectivity
  - Health endpoints
- **Security**: Runs as user 1001 (non-root)
- **Scaling**: HPA enabled (CPU/Memory based)

---

## 🛠️ Operations

### Access ArgoCD UI

```bash
# Get admin password
ARGOCD_PASSWORD=$(oc get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d)

# Get ArgoCD URL
ARGOCD_URL=$(oc get route argocd-server -n argocd -o jsonpath='{.spec.host}')

echo "URL: https://$ARGOCD_URL"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

### Manual Sync

```bash
# Sync all applications
argocd app sync -l app.kubernetes.io/part-of=mizrahi-bank

# Sync specific app
argocd app sync app-account-service

# Hard refresh
argocd app sync app-mainframe-mock --force --prune
```

### View Logs

```bash
# Mainframe mock logs
oc logs -n mizrahi-core -l app.kubernetes.io/name=mainframe-mock -f

# Account service logs
oc logs -n mizrahi-core -l app.kubernetes.io/name=account-service -f

# Kafka logs
oc logs -n mizrahi-core mizrahi-cluster-kafka-0 -c kafka
```

### Scale Applications

```bash
# Scale via kubectl
oc scale deployment account-service -n mizrahi-core --replicas=5

# Or update values.yaml and commit (GitOps way - recommended)
```

---

## 🐛 Troubleshooting

### Application Not Syncing

```bash
# Check application status
argocd app get app-account-service

# View sync errors
argocd app sync app-account-service --dry-run

# Force refresh from Git
argocd app get app-account-service --refresh
```

### Container Security Errors

If you see "container has runAsNonRoot and image will run as root":

```yaml
# Ensure values.yaml has:
securityContext:
  runAsUser: 1001
  runAsNonRoot: true

podSecurityContext:
  runAsUser: 1001
  fsGroup: 1001
```

### Route Not Accessible

```bash
# Verify route exists
oc get route -n mizrahi-core

# Check route status
oc describe route account-service -n mizrahi-core

# Test internal service first
oc run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl http://account-service.mizrahi-core.svc:8080/health
```

### Kafka Not Ready

```bash
# Check Strimzi operator
oc get pods -n openshift-operators | grep strimzi

# Check Kafka cluster status
oc get kafka mizrahi-cluster -n mizrahi-core -o yaml

# View Kafka pod logs
oc logs -n mizrahi-core mizrahi-cluster-kafka-0
```

---

## 🔄 Development Workflow

### Making Changes

1. **Edit manifests** in your Git repository
2. **Commit and push** to the main branch
3. **ArgoCD auto-syncs** (within 3 minutes)
4. **Verify** in ArgoCD UI or CLI

```bash
# Example: Update account service replicas
vim charts/account-service/values.yaml
# Change: replicaCount: 3

git add charts/account-service/values.yaml
git commit -m "Scale account-service to 3 replicas"
git push origin main

# Watch ArgoCD sync
argocd app wait app-account-service --sync
```

### Testing Locally

```bash
# Render Helm templates
helm template apps-chart ./apps-chart

# Validate manifests
oc apply --dry-run=client -f components/infra/kafka/

# Lint Helm charts
helm lint charts/account-service
helm lint charts/mainframe-mock
```

---

## 🗑️ Cleanup

### Remove Everything

```bash
# Delete root application (cascades to all children)
oc delete application mizrahi-root -n argocd

# Wait for all resources to be removed
oc get applications -n argocd -w

# Clean up namespace
oc delete namespace mizrahi-core
```

### Remove Specific Component

```bash
# Disable in values.yaml
vim apps-chart/values.yaml
# Set: applications.accountService.enabled: false

# Commit and push
git commit -am "Disable account service"
git push

# ArgoCD will prune the resources automatically
```

---

## 📚 API Examples

### Mainframe Mock

```bash
MAINFRAME_URL=$(oc get route mainframe-mock -n mizrahi-core -o jsonpath='{.spec.host}')

# Health check
curl https://$MAINFRAME_URL/health

# Status
curl https://$MAINFRAME_URL/status

# Account lookup
curl https://$MAINFRAME_URL/account/123456

# Transaction
curl -X POST https://$MAINFRAME_URL/transaction \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "ILS"}'
```

### Account Service

```bash
ACCOUNT_URL=$(oc get route account-service -n mizrahi-core -o jsonpath='{.spec.host}')

# Health
curl https://$ACCOUNT_URL/health

# Ready
curl https://$ACCOUNT_URL/health/ready
```

---

## 📖 Additional Resources

- [Bootstrap README](bootstrap/README.md) - Detailed bootstrap guide
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [OpenShift GitOps](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
- [Strimzi Kafka Operator](https://strimzi.io/)

---

## 🤝 Contributing

### Directory Conventions

- `/bootstrap` - Root application only
- `/apps-chart` - ArgoCD Application generators
- `/charts` - Application Helm charts
- `/components/infra` - Infrastructure manifests

### Naming Conventions

- **Resources**: `<service-name>` (lowercase, hyphenated)
- **ArgoCD Apps**: `infra-*` or `app-*` prefix
- **Labels**: Include `component`, `service`, `managed-by`

---

## 📄 License

Internal use - Mizrahi Bank DevOps Team

## 📧 Support

For issues or questions, contact: **devops@mizrahi.bank**

---

**🏦 Built with ❤️ by Mizrahi Bank DevOps Team**

**Pattern**: App-of-Apps | **Platform**: OpenShift | **GitOps**: ArgoCD
