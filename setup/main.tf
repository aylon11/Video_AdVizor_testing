#############################################
# Vars
#############################################

variable "project_id" {
  type = string
}

variable "project_number" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "location" {
  type    = string
  default = "US"
}

variable "annotator_job_name" {
  type    = string
  default = "advizor-annotator"
}

variable "dataset_id" {
  type = string
  default = "video_data"
}

variable "annotations_table_id" {
  type = string
  default = "video_annotations"
}

locals {
  service_account = "${var.project_number}-compute@developer.gserviceaccount.com"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_container_registry_image" "annotator_image" {
  name = "gcr.io/${var.project_id}/${var.annotator_job_name}:latest"
}

#############################################
# IAM
#############################################

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${local.service_account}"
}

resource "google_project_iam_member" "bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${local.service_account}"
}

resource "google_project_iam_member" "run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${local.service_account}"
}

# resource "google_project_iam_member" "function_viewer" {
#   project = var.project_id
#   role    = "roles/cloudfunctions.viewer"
#   member  = "serviceAccount:${local.service_account}"
# }

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${local.service_account}"
}

# resource "google_project_iam_member" "eventarc_event_receiver" {
#   project = var.project_id
#   role    = "roles/eventarc.eventReceiver"
#   member  = "serviceAccount:${local.service_account}"
# }

resource "google_project_iam_member" "service_account_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${local.service_account}"
}

# resource "google_project_iam_member" "eventarc_admin" {
#   project = var.project_id
#   role    = "roles/eventarc.admin"
#   member  = "serviceAccount:${local.service_account}"
# }

resource "google_project_iam_member" "pubsub_service_account_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

#############################################
# Cloud Run
#############################################

resource "google_cloud_run_v2_job" "video_advizor_job" {
  name     = "${var.annotator_job_name}-job"
  location = var.region
  template {
    template {
      containers {
        image = data.google_container_registry_image.annotator_image.name
        resources {
          limits = {
            cpu    = "2"
            memory = "2048Mi"
          }
        }
        env {
          name = "PROJECT_NAME"
          value = var.project_id
        }
        env {
          name = "PROJECT_NUMBER"
          value = var.project_number
        }
      }
      timeout = "43200s"
      max_retries = 1
    }
  }
}

## Scheduler Trigger

resource "google_cloud_scheduler_job" "annotator_scheduler" {
  name             = "${var.annotator_job_name}-scheduler"
  schedule         = "30 1 * * *"
  attempt_deadline = "320s"
  region           = "us-central1"
  project          = var.project_id

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_number}/jobs/${var.annotator_job_name}-job:run"

    oauth_token {
      service_account_email = local.service_account
    }
  }

  depends_on = [google_cloud_run_v2_job.video_advizor_job]
}