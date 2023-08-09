resource "kubectl_manifest" "nginx_application" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: nginx
      namespace: ${kubernetes_namespace.argocd.metadata[0].name}
    spec:
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
      destination:
        server: "https://kubernetes.default.svc"
        namespace: ${kubernetes_namespace.nginx.metadata[0].name}
      project: default
      source:
        chart: ingress-nginx
        repoURL: https://kubernetes.github.io/ingress-nginx
        targetRevision: "4.6.1"
        helm:
          values: |
           controller:
             extraArgs:
               publish-status-address: "127.0.0.1"
             hostPort:
               enabled: true
               ports:
                 http: 80
                 https: 443
             nodeSelector:
               "ingress-ready": "true"
               "kubernetes.io/os": "linux"
             publishService:
               enabled: false
             service:
               type: "NodePort"
  YAML

  depends_on = [kubernetes_job_v1.wait_argocd_crd]
}

resource "kubernetes_namespace" "nginx" {
  metadata { name = "nginx" }
}
