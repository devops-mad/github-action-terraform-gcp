# Enterprise GCP Terraform Infrastructure

Production-ready, highly modular Terraform codebase provisioning a cost-optimized development environment on Google Cloud Platform (GCP) following enterprise security baselines.

---

## Architecture Overview

```
                      +---------------------------------------------------+
                      |                    Custom VPC                     |
                      |                                                   |
                      |   +-------------------+   +-------------------+   |
                      |   | Cloud Run v2      |   | GKE Autopilot     |   |
                      |   | (Direct VPC       |   | (Private Cluster) |   |
                      |   |  Egress)          |   |                   |   |
                      |   +---------+---------+   |  +-------------+  |   |
                      |             |             |  | Cloud SQL   |  |   |
                      |             |             |  | Proxy       |  |   |
                      |             |             |  | (DaemonSet) |  |   |
                      |             |             |  +------+------+  |   |
                      |             |             +---------|---------+   |
                      |             +---------+-------------+             |
                      |                       |                           |
                      |                       v                           |
                      |           +-----------------------+               |
                      |           | Private Services      |               |
                      |           | Access (PSA Peering)  |               |
                      |           +-----------+-----------+               |
                      +-----------------------|---------------------------+
                                              v
                              +-------------------------------+
                              | Cloud SQL (PostgreSQL 15)     |
                              | - Private IP Only (No Public) |
                              | - Minimal Tier (db-f1-micro)  |
                              +-------------------------------+

                      +---------------------------------------------------+
                      |               Remote State Backend                |
                      |                                                   |
                      |   +-------------------------------------------+   |
                      |   | GCS Bucket: terraform-state-$PROJECT_ID   |   |
                      |   | - Object Versioning & Rollback Protection |   |
                      |   | - Atomic Generation-Match State Locking   |   |
                      |   | - Enforced Uniform Bucket-Level Access    |   |
                      |   | - Public Access Prevention Enforced       |   |
                      |   +-------------------------------------------+   |
                      +---------------------------------------------------+
```

---

## Directory Structure

```
.
├── backend.tf                 # Partial GCS remote state backend configuration
├── backend.tfvars             # Dynamic backend parameter configuration
├── main.tf                    # Root module orchestration & module wiring
├── variables.tf               # Global parameter definitions with strict typing
├── outputs.tf                 # Unified outputs from all provisioned subsystems
├── providers.tf               # Provider declarations (google, google-beta, kubernetes, random)
├── terraform.tfvars           # Default dev variable assignments
├── README.md                  # Architecture documentation and execution guide
└── modules/
    ├── vpc/                   # Custom VPC, secondary ranges, PSA peering, firewall rules
    ├── artifact_registry/     # Artifact Registry Docker repository
    ├── secrets/               # Secret Manager with dynamic password generation
    ├── database/              # Cloud SQL PostgreSQL (private IP only, minimal tier)
    ├── gke/                   # GKE Autopilot private cluster with Workload Identity
    ├── cloud_run/             # Cloud Run v2 with Direct VPC Egress & Secret injection
    └── gke_workloads/         # Cloud SQL Auth Proxy DaemonSet + Workload Identity binding
```

---

## Architectural Rationale & Key Decisions

### 1. Pre-Created GCS State Bucket via `gcloud` (Industry Best Practice)
Pre-creating the state bucket via `gcloud` and defining a partial backend in `backend.tf` is the **recommended industry standard** for cloud teams:
- **Single Unified Codebase**: Eliminates unnecessary auxiliary subfolders (e.g. `bootstrap/`) and avoids the complexity of maintaining a separate Terraform state just for the state bucket.
- **Environment Decoupling**: Defining only `prefix = "terraform/state"` in `backend.tf` allows the bucket name to be injected dynamically during `terraform init -backend-config=...`. The same codebase can be promoted across `dev`, `staging`, and `prod` without modifying HCL files.
- **Native Atomic Locking**: Google Cloud Storage natively supports object-generation preconditions (`x-goog-if-generation-match`). Terraform uses this for distributed state locking without requiring any external lock table (e.g. DynamoDB).
- **Enterprise Security**: Configured with `--uniform-bucket-level-access`, `--public-access-prevention`, and `--versioning` for instant rollback and protection against accidental corruption.

### 2. Cloud Run Image from Private Artifact Registry
- **Least Privilege Access**: The Cloud Run runtime Service Account is explicitly assigned `roles/artifactregistry.reader`, granting it secure access to pull container images directly from your private Artifact Registry repository.
- **Dynamic Image Configuration**: Setting `cloud_run_image = null` in `terraform.tfvars` automatically resolves to `${region}-docker.pkg.dev/${project_id}/${artifact_registry_repo_id}/app:latest`.
- **Fast Seeding for POCs**: You can easily seed your Artifact Registry with a starter container using Google's direct image-copy command (no local Docker daemon required).

### 3. Cloud Run Direct VPC Egress vs Serverless VPC Access Connector
- **Legacy Connector Drawback**: Traditional Serverless VPC Access Connectors require at least 2 dedicated `e2-micro` or `f1-micro` VM instances running continuously, incurring ~$18+/month fixed overhead per connector even with zero application traffic, and introducing network throughput bottlenecks.
- **Direct VPC Egress Advantage**: Modern Cloud Run v2 supports Direct VPC Egress (`vpc_access.network_interfaces`). Traffic is attached directly to the Google Andromeda SDN without intermediate connector VMs. This delivers lower latency, eliminates fixed idle costs, and simplifies IP space allocation.
- **Traffic Routing**: Configured with `egress = "PRIVATE_RANGES_ONLY"`. RFC 1918 traffic (including Cloud SQL Private Services Access peering) routes directly into the VPC, while general internet traffic exits through Google's optimized edge.

### 4. GKE Autopilot DaemonSet Constraints & Compliance
GKE Autopilot enforces automated node provisioning and strict admission controllers:
- **Mandatory Resource Requests**: Autopilot rejects pods that do not declare explicit CPU and Memory requests. The manifest defines `cpu: 250m` and `memory: 512Mi` (compliant with Autopilot compute sizing increments).
- **Restricted Pod Security Standard (PSS)**: Autopilot strictly forbids `hostNetwork: true` and `privileged: true` on regular workloads. The Cloud SQL Auth Proxy DaemonSet is configured without `hostNetwork`, runs as non-root UID `65532`, drops all capabilities (`ALL`), and applies `RuntimeDefault` seccomp profiles.
- **Workload Identity**: No GCP service account JSON keys are created or mounted. The Kubernetes Service Account (`KSA`) in the `cloudsql-proxy` namespace is annotated with the Google Service Account (`GSA`), and granted `roles/iam.workloadIdentityUser`. The GSA is assigned `roles/cloudsql.client`.
- **Inter-Pod Discovery**: A Kubernetes `ClusterIP` Service (`cloud-sql-proxy-service`) exposes the DaemonSet across the cluster at `cloud-sql-proxy-service.cloudsql-proxy.svc.cluster.local:5432`.

### 5. Cloud SQL Private IP & Dependency Sequencing
- **Zero Public Exposure**: `ipv4_enabled = false` guarantees that the database has no public IP address and is completely inaccessible from the public internet.
- **PSA Peering Dependency**: Cloud SQL private IP creation strictly requires the Service Networking connection (`servicenetworking.googleapis.com`) to be active before instance initialization. The module takes `psa_connection_id` as an explicit input to enforce deterministic provisioning order.
- **Deletion Safeguard**: Configured with `deletion_policy = "ABANDON"` on the PSA connection so tear-down operations do not get blocked by Google Cloud's tenant VPC peering.
- **Name Collision Safeguard**: Cloud SQL instance names cannot be immediately reused upon deletion. A `random_id` 4-byte suffix ensures collision-free recreation during iteration.

### 6. Secret Management & Dynamic Generation
- **Zero Plain-Text Credentials**: Passwords are not committed to code or static files. If `cloud_sql_password` is left `null` in `terraform.tfvars`, Terraform generates a cryptographically secure 24-character password via `random_password` and immediately stores it in Secret Manager.
- **Least-Privilege Secret Access**: The Cloud Run runtime service account is granted `roles/secretmanager.secretAccessor` only on the exact secrets it requires, rather than project-wide.

---

## Step-by-Step Deployment Guide

### Prerequisites
1. [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install) installed and authenticated.
2. [Terraform CLI (>= 1.5.0)](https://developer.hashicorp.com/terraform/downloads) installed.
3. GCP APIs enabled on your project:
   ```bash
   gcloud services enable \
     storage.googleapis.com \
     compute.googleapis.com \
     container.googleapis.com \
     servicenetworking.googleapis.com \
     sqladmin.googleapis.com \
     secretmanager.googleapis.com \
     artifactregistry.googleapis.com \
     run.googleapis.com
   ```

---

### Step 1: Create and Harden the GCS State Bucket

Run the following commands using `gcloud` (or Cloud Shell / bash / PowerShell):

```bash
# Set your environment variables
export PROJECT_ID="your-actual-gcp-project-id"
export REGION="me-central2"  # or us-east1 / us-central1

# Configure gcloud project
gcloud config set project $PROJECT_ID

# 1. Create the bucket with standard class, uniform access, and public access prevention
gcloud storage buckets create gs://terraform-state-$PROJECT_ID \
  --location=$REGION \
  --default-storage-class=standard \
  --uniform-bucket-level-access \
  --public-access-prevention

# 2. Enable object versioning for disaster recovery & rollback protection
gcloud storage buckets update gs://terraform-state-$PROJECT_ID --versioning
```

---

### Step 2: (Optional) Seed Artifact Registry with an Initial Image

Before Cloud Run can deploy an image from your private Artifact Registry, at least one container image must exist with the tag `app:latest`.
You can copy a starter image directly into your registry in one command (no local Docker required):

```bash
gcloud artifacts docker images copy \
  us-docker.pkg.dev/cloudrun/container/hello:latest \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/dev-docker-repo/app:latest
```

---

### Step 3: Configure Terraform Variables

1. Edit [terraform.tfvars](file:///M:/Projects/said/terraform.tfvars) and set your target Project ID and Region:
   ```hcl
   project_id = "your-actual-gcp-project-id"
   region     = "me-central2"  # or us-east1

   # If set to null, Cloud Run will automatically target your Artifact Registry:
   # "${region}-docker.pkg.dev/${project_id}/dev-docker-repo/app:latest"
   cloud_run_image = null
   ```

2. Edit [backend.tfvars](file:///M:/Projects/said/backend.tfvars):
   ```hcl
   bucket = "terraform-state-your-actual-gcp-project-id"
   ```

---

### Step 4: Initialize and Apply

1. Initialize Terraform with the remote backend:
   ```bash
   terraform init -backend-config=backend.tfvars
   ```

2. Review the execution plan:
   ```bash
   terraform plan
   ```

3. Apply the infrastructure:
   ```bash
   terraform apply
   ```

---

### Step 5: Verify Deployment

1. **Verify State in GCS**:
   ```bash
   gcloud storage ls gs://terraform-state-$PROJECT_ID/terraform/state/default.tfstate
   ```

2. **Verify Cloud Run Deployment**:
   ```bash
   gcloud run services describe dev-app-service --region=$REGION --format="value(status.url)"
   ```

3. **Verify GKE DaemonSet & Database**:
   ```bash
   terraform output
   ```
