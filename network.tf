# VPC 1: Monitor
resource "google_compute_network" "vpc_1" {
  name                    = "vpc-1"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "monitor_subnet" {
  name                     = "private-monitor-subnet"
  ip_cidr_range            = "10.10.10.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc_1.id
  private_ip_google_access = true
}

# VPC 2: Exposed
resource "google_compute_network" "vpc_2" {
  name                    = "vpc-2"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "exposed_subnet" {
  name                     = "private-exposed-subnet"
  ip_cidr_range            = "10.20.20.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc_2.id
  private_ip_google_access = false
}

# VPC Peering
resource "google_compute_network_peering" "peering_1_to_2" {
  name         = "vpc-peering-1-to-2"
  network      = google_compute_network.vpc_1.self_link
  peer_network = google_compute_network.vpc_2.self_link
}

resource "google_compute_network_peering" "peering_2_to_1" {
  name         = "vpc-peering-2-to-1"
  network      = google_compute_network.vpc_2.self_link
  peer_network = google_compute_network.vpc_1.self_link
}

# Cloud Router & NAT (Deleted during Post-Config)
resource "google_compute_router" "nat_router" {
  count   = var.post_config_applied ? 0 : 1
  name    = "nat-router"
  network = google_compute_network.vpc_1.name
  region  = var.region
}

resource "google_compute_router_nat" "monitor_nat" {
  count                              = var.post_config_applied ? 0 : 1
  name                               = "monitor-nat"
  router                             = google_compute_router.nat_router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Public IP for Honeypot
resource "google_compute_address" "exposed_public_ip" {
  name   = "exposed-static-public-ip"
  region = var.region
}