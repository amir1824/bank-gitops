# Bootstrap - Mizrahi Bank GitOps

This directory contains the **entry point** for the entire GitOps deployment using ArgoCD's "App of Apps" pattern.

## 📋 Overview

The bootstrap process involves **ONE manual step**: applying the root application manifest. After that, ArgoCD manages everything automatically.

```
┌─────────────────────────────────────┐
│  Manual Apply (ONE TIME)            │
│  oc apply -f root-app.yaml          │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  ArgoCD Root Application            │
│  (Monitors: /apps-chart)            │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Apps Chart (Helm)                  │
│  Generates ArgoCD Applications      │
└────────────┬────────────────────────┘
             │
      ┌──────┴──────┐
      ▼             ▼
┌──────────┐  ┌──────────┐
│  Infra   │  │   Apps   │
│  Apps    │  │  Apps    │
└──────────┘  └──────────┘
```

## 🚀 Deployment Steps

### Prerequisites

1. **OpenShift Cluster** (4.12+)
2. **ArgoCD Installed** in the `argocd` namespace
   ```bash
   # Install ArgoCD Operator via OperatorHub or:
   oc create namespace argocd
   oc apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

3. **Strimzi Kafka Operator** (for Kafka infrastructure)
   ```bash
   # Install via OpenShift OperatorHub
   # Or manually:
   oc create namespace kafka
   oc apply -f https://strimzi.io/install/latest?namespace=kafka -n kafka
   ```

### Step 1: Deploy the Root Application

```bash
# Navigate to the repository root
cd /path/to/bank-gitops

# Apply the root application (App of Apps)
oc apply -f bootstrap/root-app.yaml
```

**Expected Output:**
```
application.argoproj.io/mizrahi-root created
```

### Step 2: Verify Deployment

```bash
# Check if the root application is created
oc get application -n argocd mizrahi-root

# Watch ArgoCD sync the apps-chart
oc get applications -n argocd -w

# Expected applications after sync:
# - mizrahi-root (the bootstrap app)
# - infra-kafka
# - infra-redis  
# - app-mainframe-mock
# - app-account-service
```

### Step 3: Access ArgoCD UI

```bash
# Get ArgoCD admin password
ARGOCD_PASSWORD=$(oc get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d)

echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# Get ArgoCD Route URL
ARGOCD_URL=$(oc get route argocd-server -n argocd -o jsonpath='{.spec.host}')

echo "ArgoCD URL: https://$ARGOCD_URL"
```

Login with:
- **Username:** `admin`
- **Password:** (from above command)

### Step 4: Apply Cluster Resources (Optional)

```bash
# Add ArgoCD console link to OpenShift UI
oc apply -f bootstrap/cluster-resources/consolelink.yaml
```

## 🔧 Configuration

### Environment Selection

Edit `root-app.yaml` to change the environment:

```yaml
helm:
  values: |
    global:
      environment: prod  # Change from 'dev' to 'prod'
```

### Enable/Disable Components

Toggle individual services in `root-app.yaml`:

```yaml
helm:
  values: |
    infrastructure:
      kafka:
        enabled: true   # Set to false to disable Kafka
      redis:
        enabled: false  # Disable Redis
    
    applications:
      mainframeMock:
        enabled: true
      accountService:
        enabled: false  # Disable account service
```

After making changes:
```bash
oc apply -f bootstrap/root-app.yaml
# ArgoCD will detect changes and sync automatically
```

## 📁 Directory Structure

```
bootstrap/
├── root-app.yaml              # The main entry point (ArgoCD Application)
├── cluster-resources/         # Cluster-wide resources
│   └── consolelink.yaml      # OpenShift console integration
└── README.md                 # This file
```

## 🛠️ Troubleshooting

### Application Not Syncing

```bash
# Check application status
argocd app get mizrahi-root

# Force sync
argocd app sync mizrahi-root --force

# Check ArgoCD application controller logs
oc logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

### Child Applications Not Created

```bash
# Verify the apps-chart Helm chart renders correctly
helm template mizrahi-apps ./apps-chart

# Check for syntax errors in values
helm lint ./apps-chart
```

### Permission Issues

```bash
# Verify ArgoCD has necessary permissions
oc get clusterrolebinding | grep argocd

# Grant ArgoCD cluster-admin (for dev/testing only)
oc adm policy add-cluster-role-to-user cluster-admin \
  system:serviceaccount:argocd:argocd-application-controller
```

## 🔄 Updating the Stack

### Method 1: Git-based (Recommended)

1. Make changes to manifests in Git
2. Commit and push
3. ArgoCD auto-syncs (if enabled) or click "Sync" in UI

### Method 2: Edit Root Application

```bash
oc edit application mizrahi-root -n argocd
# Edit values inline
# Save and exit - ArgoCD will sync changes
```

## 🗑️ Cleanup

To remove the entire stack:

```bash
# Delete the root application (cascades to all children)
oc delete application mizrahi-root -n argocd

# Verify all applications are removed
oc get applications -n argocd

# Clean up namespaces if needed
oc delete namespace mizrahi-core
```

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [OpenShift GitOps Operator](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)

---

**Next Steps:** Review the `apps-chart/` directory to understand how Application manifests are generated.
