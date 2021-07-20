variable "databricks_connection_profile" {
  description = "christopher_chalcraft-ws"
  type = string
  default = "GCP"
}

terraform {
  required_providers {
    databricks = {
      source = "databrickslabs/databricks"
      version = "0.3.2"
    }

    google = {
      source = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "databricks" {
  profile = var.databricks_connection_profile
}

provider "google" {}

variable "resource_prefix" {
  description = "The prefix to use when naming the notebook and job"
  type = string
  default = "cchalc-terraform-demo"
}

variable "email_notifier" {
  description = "The email address to send job status to"
  type = list(string)
  default = ["christopher.chalcraft@databricks.com"]
}

// Get information about the Databricks user that is calling
// the Databricks API (the one associated with "databricks_connection_profile").
data "databricks_current_user" "me" {}

// Create a simple, sample notebook. Store it in a subfolder within
// the Databricks current user's folder. The notebook contains the
// following basic Spark code in Python.
resource "databricks_notebook" "this" {
  path     = "${data.databricks_current_user.me.home}/Terraform/${var.resource_prefix}-notebook.ipynb"
  language = "PYTHON"
  content_base64 = base64encode(<<-EOT
    # created from ${abspath(path.module)}
    display(spark.range(10))
    EOT
  )
}

// Create a job to run the sample notebook. The job will create
// a cluster to run on. The cluster will use the smallest available
// node type and run the latest version of Spark.

// Get the smallest available node type to use for the cluster. Choose
// only from among available node types with local storage.
data "databricks_node_type" "smallest" {
  local_disk = true
}

// Get the latest Spark version to use for the cluster.
data "databricks_spark_version" "latest" {}

// Create the job, emailing notifiers about job success or failure.
resource "databricks_job" "this" {
  name = "${var.resource_prefix}-job-${data.databricks_current_user.me.alphanumeric}"
  new_cluster {
    num_workers   = 1
    spark_version = data.databricks_spark_version.latest.id
    node_type_id  = data.databricks_node_type.smallest.id
  }
  notebook_task {
    notebook_path = databricks_notebook.this.path
  }
  email_notifications {
    on_success = var.email_notifier
    on_failure = var.email_notifier
  }
}

// Print the URL to the notebook.
output "notebook_url" {
  value = databricks_notebook.this.url
}

// Print the URL to the job.
output "job_url" {
  value = databricks_job.this.url
}

