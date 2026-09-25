/**
 * GKE Kubernetes Resources Module (Cloud SQL Auth Proxy DaemonSet)
 *
 * Deploys the Cloud SQL Auth Proxy as a DaemonSet inside a GKE Autopilot cluster,
 * integrated securely with Google Cloud using Workload Identity.
 *
 * ============================================================================
 * CRITICAL GKE AUTOPILOT DAEMONSET CONSTRAINTS & DESIGN RATIONALE:
 * ============================================================================
 * 1. Resource Allocations:
 *    - In GKE Autopilot, pods CANNOT have arbitrary or missing resource requests.
 *    - Explicit CPU (e.g. 250m) and Memory (e.g. 512Mi) requests MUST be declared.
 *    - Autopilot validates that requests adhere to allowed minimum increments and
 *      automatically harmonizes requests with limits to ensure predictable billing
 *      and node autoscaling.
 *
 * 2. Security Context & Pod Security Standards (PSS):
 *    - Autopilot strictly enforces the Kubernetes 'Restricted' Pod Security Standard.
 *    - 'hostNetwork = true' and 'privileged = true' are FORBIDDEN on Autopilot
 *      to maintain strict kernel isolation across dynamically managed nodes.
 *    - The container must run as non-root (run_as_non_root = true, run_as_user = 65532),
 *      drop all Linux capabilities (drop = ["ALL"]), and employ RuntimeDefault seccomp.
 *
 * 3. Workload Identity Integration:
 *    - Autopilot operates Workload Identity natively (<project_id>.svc.id.goog).
 *    - No service account keys are stored or mounted onto the cluster.
 *    - The Kubernetes Service Account (KSA) is annotated with the Google Service Account (GSA) email.
 *    - The GSA receives 'roles/iam.workloadIdentityUser' granting the KSA permission to impersonate it.
 *    - The GSA is granted 'roles/cloudsql.client' on the GCP project.
 */

# -----------------------------------------------------------------------------
# Google Service Account (GSA) for Workload Identity
# -----------------------------------------------------------------------------
resource "google_service_account" "proxy_gsa" {
  account_id   = var.gsa_name
  display_name = "Cloud SQL Auth Proxy GSA for GKE Autopilot"
  project      = var.project_id
}

# Grant Cloud SQL Client role to GSA
resource "google_project_iam_member" "proxy_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.proxy_gsa.email}"
}

# Allow KSA to impersonate GSA via Workload Identity
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.proxy_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.ksa_name}]"

  depends_on = [
    kubernetes_namespace.proxy_ns,
    kubernetes_service_account.proxy_ksa
  ]
}

# -----------------------------------------------------------------------------
# Kubernetes Resources
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "proxy_ns" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "cloudsql-proxy"
    }
  }
}

resource "kubernetes_service_account" "proxy_ksa" {
  metadata {
    name      = var.ksa_name
    namespace = kubernetes_namespace.proxy_ns.metadata[0].name
    annotations = {
      # Workload Identity binding annotation
      "iam.gke.io/gcp-service-account" = google_service_account.proxy_gsa.email
    }
  }
}

resource "kubernetes_daemon_set_v1" "cloudsql_proxy" {
  metadata {
    name      = "cloud-sql-proxy"
    namespace = kubernetes_namespace.proxy_ns.metadata[0].name
    labels = {
      app = "cloud-sql-proxy"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "cloud-sql-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloud-sql-proxy"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.proxy_ksa.metadata[0].name

        # Autopilot constraint: hostNetwork must NOT be enabled for standard workloads
        host_network = false

        security_context {
          run_as_non_root = true
          run_as_user     = 65532
          fs_group        = 65532
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "cloud-sql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.14.0"

          # Use structured arguments for Cloud SQL Proxy v2
          args = [
            "--address",
            "0.0.0.0",
            "--port",
            tostring(var.proxy_port),
            var.instance_connection_name
          ]

          port {
            name           = "postgres-proxy"
            container_port = var.proxy_port
            protocol       = "TCP"
          }

          # Autopilot constraint: CPU and Memory requests are mandatory
          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 65532
            capabilities {
              drop = ["ALL"]
            }
          }

          liveness_probe {
            http_get {
              path = "/startup"
              port = 9090
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/startup"
              port = 9090
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    google_service_account_iam_member.workload_identity_user
  ]
}

# Cluster-internal Service to allow any Pod to easily connect to the DaemonSet Proxy
resource "kubernetes_service" "proxy_service" {
  metadata {
    name      = "cloud-sql-proxy-service"
    namespace = kubernetes_namespace.proxy_ns.metadata[0].name
    labels = {
      app = "cloud-sql-proxy"
    }
  }

  spec {
    selector = {
      app = "cloud-sql-proxy"
    }

    port {
      name        = "postgres"
      port        = var.proxy_port
      target_port = var.proxy_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
