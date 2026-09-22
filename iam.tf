resource "google_service_account" "wazuh_monitor" {
  account_id   = "wazuh-monitor"
  display_name = "wazuh-monitor"
}

resource "google_project_iam_member" "monitor_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.wazuh_monitor.email}"
}

resource "google_project_iam_member" "monitor_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wazuh_monitor.email}"
}

resource "google_service_account" "wazuh_agent" {
  account_id   = "wazuh-agent"
  display_name = "wazuh-agent"
}