resource "kubectl_manifest" "jaeger_application" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: jaeger
      namespace: ${kubernetes_namespace.argocd.metadata[0].name}
    spec:
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
      destination:
        server: "https://kubernetes.default.svc"
        namespace: ${kubernetes_namespace.jaeger.metadata[0].name}
      project: default
      source:
        chart: jaeger
        helm:
          values: |
            agent:
              enabled: false
            allInOne:
              enabled: true
              tag: "1.47.0"
              extraEnv:
                - name: JAEGER_AGENT_PORT
                  value: "6831"
              ingress:
                enabled: true
                ingressClassName: nginx
                hosts:
                  - "jaeger.lvh.me"
            collector:
              enabled: false
            provisionDataStore:
              cassandra: false
              elasticsearch: false
              kafka: false
            query:
              enabled: false
            storage:
              type: memory
        repoURL: https://jaegertracing.github.io/helm-charts
        targetRevision: 0.71.11
  YAML

  depends_on = [kubernetes_job_v1.wait_argocd_crd]
}

resource "kubernetes_namespace" "jaeger" {
  metadata { name = "jaeger" }
}
