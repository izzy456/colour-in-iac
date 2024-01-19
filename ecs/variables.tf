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

variable "domain_name" {
  description = "The domain name of the web app (e.g. example.com, requires setup of ACM cert for this domain and www. subdomain as well as Hosted Zone)"
  type        = string
  default     = ""
}