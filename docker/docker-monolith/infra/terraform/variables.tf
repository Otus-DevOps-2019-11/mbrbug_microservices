variable project {
  description = "Project ID"
}

variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}

variable docker_disk_image {
  description = "Disk image"
}

variable private_key_path {
  description = "path to private key"
}

variable zone {
  description = "zone for instance"
  default     = "europe-west1-b"
}

variable machine_type {
  description = "default gcp machine type"
  default     = "g1-small"
}
