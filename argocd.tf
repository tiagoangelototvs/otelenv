locals {
  argocd_crds = [
    "customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io",
    "customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io",
    "customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io",
    "customresourcedefinition.apiextensions.k8s.io/argocdextensions.argoproj.io",
  ]
}

resource "helm_release" "argocd" {
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "4.6.1"

  name      = "argocd"
  namespace = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      "fullnameOverride" = "argocd",
      "server"           = {
        "extraArgs" = ["--insecure"]
        "ingress"   = { "enabled" = true, "ingressClassName" = "nginx", "hosts" = ["argocd.${local.cluster_host}"] }
      }
      "configs" = {
        "secret" = {
          "argocdServerAdminPassword"      = bcrypt("admin"),
          "argocdServerAdminPasswordMtime" = time_static.now.rfc3339
        }
      }
    })
  ]
}

resource "time_static" "now" {}

resource "kubernetes_job_v1" "wait_argocd_crd" {
  metadata {
    name      = "wait-argocd-crd"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  spec {
    template {
      metadata {}
      spec {
        service_account_name = kubernetes_service_account_v1.wait_argocd_crd.metadata[0].name
        container {
          name    = "kubectl"
          image   = "docker.io/bitnami/kubectl:${data.kubectl_server_version.current.major}.${data.kubectl_server_version.current.minor}"
          command = ["/bin/sh", "-c"]
          args    = flatten(["wait", "--for=condition=Established", local.argocd_crds, "--timeout", "10m"])
        }
        restart_policy = "Never"
      }
    }
  }
  wait_for_completion = true

  timeouts {
    create = "10m"
    update = "10m"
  }

  depends_on = [
    kubernetes_role_binding_v1.wait_argocd_crd,
    helm_release.argocd,
  ]
}

resource "kubernetes_service_account_v1" "wait_argocd_crd" {
  metadata {
    name      = "wait-argocd-crd"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "wait_argocd_crd" {
  metadata {
    name      = "wait-argocd-crd"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.crd_reader.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.wait_argocd_crd.metadata[0].name
    namespace = kubernetes_service_account_v1.wait_argocd_crd.metadata[0].namespace
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}
