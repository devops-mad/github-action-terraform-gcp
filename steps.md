# Production CI/CD Guide: Keyless Workload Identity Federation (OIDC) on GCP

This guide walks you through setting up **Keyless Workload Identity Federation (OIDC)** to deploy your Terraform infrastructure from GitHub Actions to Google Cloud Platform without managing, storing, or rotating any static JSON service account keys.

---

## 1. How Keyless Authentication Works

Workload Identity Federation allows GitHub Actions to exchange short-lived OIDC tokens with Google Cloud's Security Token Service (STS) dynamically on each workflow run:

```
+----------------+              +----------------------+              +----------------------+
| GitHub Actions |              | GCP Security Token   |              | Target GCP Resources |
| Runner         |              | Service (STS)        |              | (VPC, GKE, SQL, etc) |
+-------+--------+              +----------+-----------+              +----------+-----------+
        |                                  |                                     |
        | 1. Request signed OIDC JWT token |                                     |
        |    (includes repo, branch, actor)|                                     |
        |--------------------------------->|                                     |
        |                                  |                                     |
        | 2. Validates GitHub signature    |                                     |
        |    & checks repo matches pool    |                                     |
        |                                  |                                     |
        | 3. Exchanges JWT for short-lived |                                     |
        |    federated GCP OAuth token     |                                     |
        |<---------------------------------|                                     |
        |                                                                        |
        | 4. Executes `terraform plan/apply` with temporary token                |
        |----------------------------------------------------------------------->|
```

### Why Keyless OIDC is the Enterprise Standard:
1. **Zero Long-Lived Secrets**: No JSON keys stored in GitHub Secrets that could be leaked, shared, or forgotten.
2. **Short-Lived Tokens**: Tokens exist only in memory during the workflow step (maximum lifetime: 1 hour) and cannot be reused afterwards.
3. **Cryptographically Locked**: GCP strictly verifies that the request originates from your specific GitHub repository (`attribute.repository == "OWNER/REPO"`).

---

## 2. Directory Structure

Your repository is pre-configured with the OIDC pipeline files:

```
.
├── .github/
│   └── workflows/
│       └── terraform.yml      # OIDC-native GitHub Actions workflow
├── .gitignore                 # Prevents sensitive state & local cache leaks
├── backend.tf                 # GCS remote state backend definition
├── backend.tfvars             # Dynamic state bucket configuration
├── main.tf                    # Root infrastructure orchestration & moved blocks
├── variables.tf               # Parameter definitions with strict typing
├── outputs.tf                 # Subsystem outputs
├── providers.tf               # Provider configurations
├── terraform.tfvars           # Default dev configuration values
├── README.md                  # Infrastructure architecture documentation
├── steps.md                   # This CI/CD guide
└── modules/                   # Reusable infrastructure modules
    ├── artifact_registry/
    ├── cloud_run/
    ├── database/
    ├── gke/
    ├── gke_workloads/
    ├── secrets/
    └── vpc/
```

---

## Step 1: Push Code to Your GitHub Repository

If you haven't created your GitHub repository yet:

1. Open [GitHub](https://github.com/) and click **New Repository**.
2. Name your repository (e.g. `gcp-terraform-infra`).
3. Select **Private** (recommended) and leave "Initialize with README" **unchecked**.
4. Click **Create repository**.

Run the following commands in your local project folder (`M:\Projects\said`):

```bash
# 1. Initialize git (if not already initialized)
git init

# 2. Stage all project files
git add .

# 3. Create initial commit
git commit -m "feat: complete modular GCP terraform infrastructure with keyless OIDC CI/CD"

# 4. Set main branch
git branch -M main

# 5. Link to your GitHub repository (replace with your actual GitHub URL)
git remote add origin https://github.com/<YOUR-GITHUB-USERNAME>/<YOUR-REPO-NAME>.git

# 6. Push code to GitHub
git push -u origin main
```

---

## Step 2: Configure Workload Identity Federation in GCP

Run the following automated script in your **Google Cloud Shell** (or terminal with `gcloud` authenticated).

> [!IMPORTANT]
> Replace `<YOUR-GITHUB-USERNAME>/<YOUR-REPO-NAME>` with your actual GitHub repository path (e.g., `octocat/gcp-terraform-infra`).

```bash
# =============================================================================
# Set Configuration Variables
# =============================================================================
export PROJECT_ID=$(gcloud config get-value project)
export GITHUB_REPO="<YOUR-GITHUB-USERNAME>/<YOUR-REPO-NAME>" # e.g. "myorg/my-infra-repo"

echo "Configuring Workload Identity Federation for Project: $PROJECT_ID and Repo: $GITHUB_REPO"

# 1. Enable Required Google Cloud APIs
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com

# 2. Create the Dedicated CI/CD Service Account
gcloud iam service-accounts create github-actions-sa \
  --description="Service Account for GitHub Actions OIDC CI/CD" \
  --display-name="github-actions-sa"

# 3. Assign Required Roles to the Service Account
# Role A: Editor for infrastructure provisioning
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

# Role B: Project IAM Admin (needed to bind roles like Secret Accessor & Cloud SQL Client)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"

# 4. Create the Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# 5. Create the OIDC Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Actions OIDC Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --attribute-condition="attribute.repository == '${GITHUB_REPO}'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# 6. Fetch Project Number
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

# 7. Bind GitHub Repository to Impersonate the Service Account
gcloud iam service-accounts add-iam-policy-binding "github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_REPO}"

# =============================================================================
# Print Your GitHub Secrets Values
# =============================================================================
echo ""
echo "========================================================================="
echo "COPY THESE VALUES INTO GITHUB REPOSITORY SECRETS:"
echo "========================================================================="
echo "GCP_PROJECT_ID: $PROJECT_ID"
echo "GCP_REGION: us-east1"
echo "GCP_TF_STATE_BUCKET: terraform-state-${PROJECT_ID}"
echo "GCP_SERVICE_ACCOUNT: github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"
echo "GCP_WORKLOAD_IDENTITY_PROVIDER: projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
echo "========================================================================="
```

---

## Step 3: Add GitHub Secrets

1. In your browser, navigate to your GitHub repository.
2. Click **Settings** (top navigation tab).
3. In the left menu, select **Secrets and variables** -> **Actions**.
4. Click **New repository secret** and add the 5 secrets printed from Step 2:

| Secret Name | Value Example | Purpose |
| :--- | :--- | :--- |
| `GCP_PROJECT_ID` | `qwiklabs-gcp-03-69b30d9a1b2d` | Your GCP Project ID |
| `GCP_REGION` | `us-east1` (or `me-central2`) | Primary infrastructure region |
| `GCP_TF_STATE_BUCKET` | `terraform-state-qwiklabs-gcp-03-69b30d9a1b2d` | GCS Bucket for remote state |
| `GCP_SERVICE_ACCOUNT` | `github-actions-sa@<PROJECT_ID>.iam.gserviceaccount.com` | Service account to impersonate |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/<NUM>/locations/global/workloadIdentityPools/github-pool/providers/github-provider` | Full OIDC provider resource path |

> [!NOTE]
> Notice that **NO private keys or passwords** were pasted into GitHub Secrets. All credentials are generated dynamically on demand.

---

## Step 4: How the OIDC Workflow Operates

The workflow in `.github/workflows/terraform.yml` is pre-configured with the required OIDC token permission:
```yaml
permissions:
  contents: read
  id-token: write      # Required to request OIDC JWT tokens from GitHub
  pull-requests: write # Required to comment plan summaries on PRs
```

### The Authentication Step:
```yaml
- name: "Authenticate to Google Cloud via Workload Identity Federation"
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

1. **On Pull Request**:
   * Authenticates via OIDC.
   * Runs `terraform fmt -check`, `terraform init`, `terraform validate`.
   * Runs `terraform plan` and **posts the formatted plan output as a comment on the Pull Request**.
2. **On Push to `main` (Merge)**:
   * Authenticates via OIDC.
   * Runs `terraform apply -auto-approve` to provision changes directly to Google Cloud.

---

## Step 5: Test Your Pipeline

### 1. Test the "Plan on Pull Request" Flow
In your local terminal:

```bash
# 1. Create a feature branch
git checkout -b test-oidc-pipeline

# 2. Make a small non-breaking change (e.g. edit a comment in terraform.tfvars)
git commit -am "test: verify keyless OIDC plan pipeline"

# 3. Push branch to GitHub
git push -u origin test-oidc-pipeline
```

* Go to GitHub and click **Compare & pull request** -> **Create pull request**.
* Click the **Actions** tab to watch the workflow run.
* Return to the **Pull Request** discussion tab: you will see a bot comment with the plan status!

### 2. Test the "Apply on Merge" Flow
* Click **Merge pull request** on GitHub.
* Under the **Actions** tab, watch the `main` branch run execute `terraform apply -auto-approve` seamlessly.

### 3. Manual Workflow Dispatch Trigger
You can also run a plan or apply directly on demand from GitHub:
1. Go to the **Actions** tab in your repository.
2. Under **All workflows** on the left, click **Terraform CI/CD Pipeline (Keyless OIDC)**.
3. Click the **Run workflow** dropdown on the right.
4. Select `plan` or `apply` and click **Run workflow**.

---

## Step 6: Troubleshooting & Security FAQ

#### Q: What if I see `Error: google-github-actions/auth failed: ... unauthorized_client`?
* **Cause**: The GitHub repository string in your WIF binding does not match your GitHub repository URL.
* **Fix**: Ensure `GITHUB_REPO` matches the exact casing of `<USERNAME>/<REPO>` (e.g. `MyOrg/my-repo`).

#### Q: How is my repository secured against other GitHub users?
* The OIDC Provider configuration uses `--attribute-condition="attribute.repository == '${GITHUB_REPO}'"`.
* Even if another GitHub user discovered your Project Number or Provider name, Google Cloud's STS will inspect the cryptographic signature of the GitHub token and immediately reject requests originating from any repository other than yours.
