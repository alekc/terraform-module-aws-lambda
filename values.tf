variable "app_name" {
  description = "App name. Will be used in customized descriptions. If empty, a random name will be generated"
  type        = string
  default     = ""
}

variable "file_path" {
  description = "where lambda zip file is located"
}

variable "lambda_handler" {
  default = "main"
}
variable "lambda_runtime" {
  default = "go1.x"
}
variable "lambda_publish" {
  description = "if set to true, will publish a new version on file change"
  default     = false
}
variable "lambda_memory" {
  default = 128
}
variable "lambda_timeout" {
  default = 10
}

variable "lambda_environment" {
  type    = map(string)
  default = null
}

variable "api_gateway_enabled" {
  default = false
}
variable "api_gateway_protocol_type" {
  default = "HTTP"
}

variable "custom_domain_name" {
  description = "If not empty, use custom domain name for the api gateway entry point."
  default     = ""
}
variable "certificate_arn" {
  default = ""
}
