variable "prometheus-values" {}
variable "services" {
  type = map(object({
    port = string
    path = string
  }))
}