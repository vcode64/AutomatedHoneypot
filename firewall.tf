# --- VPC 1 Rules ---
resource "google_compute_firewall" "allow_iap_ssh" {
  name          = "allow-iap-ssh"
  network       = google_compute_network.vpc_1.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["monitor-instance"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_exposed_agent_data" {
  name          = "allow-exposed-agent-data"
  network       = google_compute_network.vpc_1.name
  direction     = "INGRESS"
  source_ranges = ["10.20.20.2/32"]
  target_tags   = ["monitor-instance"]
  allow {
    protocol = "tcp"
    ports    = ["1514"]
  }
}

resource "google_compute_firewall" "allow_exposed_agent_enrollment" {
  count         = var.post_config_applied ? 0 : 1 # Removed in post-config
  name          = "allow-exposed-agent-enrollment"
  network       = google_compute_network.vpc_1.name
  direction     = "INGRESS"
  source_ranges = ["10.20.20.2/32"]
  target_tags   = ["monitor-instance"]
  allow {
    protocol = "tcp"
    ports    = ["1515"]
  }
}

# --- VPC 2 Rules ---
resource "google_compute_firewall" "allow_exposed_outbound_wazuh" {
  name               = "allow-exposed-outbound-wazuh"
  network            = google_compute_network.vpc_2.name
  direction          = "EGRESS"
  priority           = 1000
  destination_ranges = ["10.10.10.2/32"]
  target_tags        = ["exposed-instance"]
  allow {
    protocol = "tcp"
    ports    = var.post_config_applied ? ["1514"] : ["1514", "1515"]
  }
}

# Post-Config Enforcements (Only during Phase 4)
resource "google_compute_firewall" "deny_exposed_metadata" {
  name               = "deny-exposed-outbound-metadata"
  network            = google_compute_network.vpc_2.name
  direction          = "EGRESS"
  priority           = 1010
  destination_ranges = ["169.254.169.254/32"]
  target_tags        = ["exposed-instance"]
  deny { protocol = "all" }
}

resource "google_compute_firewall" "deny_lateral_movement" {
  count              = var.post_config_applied ? 1 : 0
  name               = "deny-exposed-outbound-lateralmovement"
  network            = google_compute_network.vpc_2.name
  direction          = "EGRESS"
  priority           = 1020
  destination_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  target_tags        = ["exposed-instance"]
  deny { protocol = "all" }
}

resource "google_compute_firewall" "allow_outbound_http" {
  count              = var.post_config_applied ? 1 : 0
  name               = "allow-exposed-outbound-http-https"
  network            = google_compute_network.vpc_2.name
  direction          = "EGRESS"
  priority           = 2000
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["exposed-instance"]
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "deny_all_outbound" {
  count              = var.post_config_applied ? 1 : 0
  name               = "deny-exposed-all-outbound"
  network            = google_compute_network.vpc_2.name
  direction          = "EGRESS"
  priority           = 65534
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["exposed-instance"]
  deny { protocol = "all" }
}

# Honeypot Ingress
resource "google_compute_firewall" "allow_exposed_ssh" {
  name          = "allow-exposed-ssh"
  network       = google_compute_network.vpc_2.name
  direction     = "INGRESS"
  priority      = 2000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["exposed-instance"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_exposed_telnet" {
  name          = "allow-exposed-telnet"
  network       = google_compute_network.vpc_2.name
  direction     = "INGRESS"
  priority      = 2000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["exposed-instance"]
  allow {
    protocol = "tcp"
    ports    = ["23"]
  }
}