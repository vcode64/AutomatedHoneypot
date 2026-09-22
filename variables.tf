variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
}

variable "region" {
  default = "us-west1"
}

variable "zone" {
  default = "us-west1-b"
}

variable "post_config_applied" {
  description = "Set to true to apply Phase 4: Delete NAT and enforce strict egress rules."
  type        = bool
  default     = false
}