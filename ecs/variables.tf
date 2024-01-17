variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "colour-in"
}

variable "app_port" {
  description = "The port exposed internally for backend/frontend apps (cannot be 8081)"
  type        = number
  default     = 8080
}

variable "region" {
  description = "The region resources to be created in"
  type        = string
  nullable    = false
}

variable "cert_domain" {
  description = "Domain on the certificate for the app (leave empty if none)"
  type        = string
  default     = ""
}

variable "hosted_zone" {
  description = "The hosted zone for the project"
  type        = string
  default     = ""
}