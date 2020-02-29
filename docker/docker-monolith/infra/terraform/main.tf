resource "google_compute_instance" "docker" {
  count = 2 # create some docker instances
  name         = "reddit-docker-${count.index}"
  machine_type = "${var.machine_type}"
  project = "${var.project}"
  zone         = "${var.zone}"
  tags         = ["reddit-app"]
  boot_disk {
    initialize_params {
      image = "${var.docker_disk_image}"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
}

# Правило firewall
resource "google_compute_firewall" "firewall_reddit" {
  name    = "allow-reddit-default"
  network = "default"
  project = "${var.project}"
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }
  target_tags = ["reddit-app"]
}
