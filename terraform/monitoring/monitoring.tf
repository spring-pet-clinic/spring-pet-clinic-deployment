# resource "null_resource" "update_kubeconfig" {
#   provisioner "local-exec" {
#     command = "aws eks update-kubeconfig --region eu-west-1 --name spring-petclinic-ireland-eks"
#   }
# }

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
  # depends_on = [
  #   null_resource.update_kubeconfig
  # ]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  set {
    name  = "grafana.adminPassword"
    value = "MyStrongPassword123"
  }
  set {
    name  = "crds.enabled"
    value = true
  }

  values = [var.prometheus-values]

  depends_on = [
    kubernetes_namespace_v1.monitoring
  ]
}

resource "kubernetes_config_map" "petclinic_dashboard" {
  metadata {
    name      = "petclinic-dashboard"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "petclinic-dashboard.json" =  file("${path.module}/../../observability/grafana/dashboards/petclinic-dashboard.json")
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

resource "helm_release" "zipkin" {
  name       = "zipkin"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

  repository = "https://openzipkin.github.io/zipkin"
  chart      = "zipkin"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    helm_release.kube_prometheus_stack
  ]
}