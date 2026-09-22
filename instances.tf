resource "google_compute_instance" "monitor_instance" {
  name         = "monitor-instance"
  machine_type = "e2-standard-4"
  zone         = var.zone
  tags         = ["monitor-instance"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      type  = "pd-balanced"
      size  = 50
    }
  }

  network_interface {
    network    = google_compute_network.vpc_1.id
    subnetwork = google_compute_subnetwork.monitor_subnet.id
    network_ip = "10.10.10.2"
  }

  service_account {
    email  = google_service_account.wazuh_monitor.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "TRUE"
    ssh-keys               = "analyst:${file("~/.ssh/monitor_instance_key.pub")}"
  }

  metadata_startup_script = file("scripts/monitor_startup.sh")
}

resource "google_compute_instance" "exposed_instance" {
  name         = "exposed-instance"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["exposed-instance"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      type  = "pd-balanced"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.vpc_2.id
    subnetwork = google_compute_subnetwork.exposed_subnet.id
    network_ip = "10.20.20.2"
    access_config {
      nat_ip = google_compute_address.exposed_public_ip.address
    }
  }

  service_account {
    email  = google_service_account.wazuh_agent.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "TRUE"
  }

  metadata_startup_script = file("scripts/exposed_startup.sh")
}