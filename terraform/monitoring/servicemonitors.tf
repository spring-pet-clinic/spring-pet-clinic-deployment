# ServiceMonitors are created by the kube-prometheus-stack helm chart
# and managed via kubectl/helm, not Terraform
#
# resource "kubernetes_manifest" "servicemonitors" {
#   for_each = var.services
#
#   manifest = {
#     apiVersion = "monitoring.coreos.com/v1"
#     kind       = "ServiceMonitor"
#
#     metadata = {
#       name      = each.key
#       namespace = "monitoring"
#
#       labels = {
#         release = "kube-prometheus-stack"
#       }
#     }
#
#     spec = {
#       selector = {
#         matchLabels = {
#           app = each.key
#         }
#       }
#
#       namespaceSelector = {
#         any = true
#       }
#
#       endpoints = [
#         {
#           port     = each.value.port
#           path     = each.value.path
#           interval = "15s"
#         }
#       ]
#     }
#   }
#
#   depends_on = [
#     helm_release.kube_prometheus_stack
#   ]
# }