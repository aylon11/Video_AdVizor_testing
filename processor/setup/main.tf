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
variable "job_name" {
  type    = string
  default = "advizor_proccesor"
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

data "google_container_registry_image" "video_advizor_processor_image" {
  name = "gcr.io/${var.project_id}/${var.job_name}:latest"
}

resource "google_cloud_run_v2_job" "video_advizor_job" {
  name     = "${var.job_name}-job"
  location = var.region
  template {
    template {
      containers {
        image = data.google_container_registry_image.video_advizor_processor_image.name
        env {
          name = "PROJECT_NAME"
          value = var.project_id
        }
        env {
          name = "PROJECT_NUMBER"
          value = var.project_number
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}
