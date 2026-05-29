# Monitoring Stack - Prometheus, Grafana, and Loki
# Deployed in-cluster using Helm charts for native Kubernetes service discovery

# ============================================================================
# Grafana CloudWatch Access (IRSA)
# ============================================================================

# IAM policy for Grafana to access CloudWatch metrics and logs
resource "aws_iam_policy" "grafana_cloudwatch_policy" {
  name        = "${var.project_name}-grafana-cloudwatch"
  description = "Policy for Grafana to read CloudWatch metrics and logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-grafana-cloudwatch"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# IRSA role for Grafana to assume
module "grafana_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-grafana"

  role_policy_arns = {
    cloudwatch = aws_iam_policy.grafana_cloudwatch_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["monitoring:kube-prometheus-stack-grafana"]
    }
  }

  tags = {
    Name        = "${var.project_name}-grafana"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ============================================================================
# kube-prometheus-stack (Prometheus + Grafana + Exporters)
# ============================================================================

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "85.1.0"
  timeout          = 900 # 15 minutes for large chart deployment
  wait             = true
  wait_for_jobs    = true

  set = [
    # Grafana configuration
    {
      name  = "grafana.enabled"
      value = "true"
    },
    {
      name  = "grafana.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.grafana_irsa.iam_role_arn
      type  = "string"
    },
    {
      name  = "grafana.persistence.enabled"
      value = "true"
    },
    {
      name  = "grafana.persistence.size"
      value = "10Gi"
    },
    {
      name  = "grafana.persistence.storageClassName"
      value = "ebs-gp3"
    },
    # Grafana admin credentials (use Secrets Manager in production)
    {
      name  = "grafana.adminPassword"
      value = "admin" # TODO: Replace with Secrets Manager reference
    },
    # Prometheus configuration
    {
      name  = "prometheus.prometheusSpec.retention"
      value = "15d"
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
      value = "ReadWriteOnce"
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
      value = "50Gi"
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
      value = "ebs-gp3"
    },
    # Enable service monitors for pod discovery
    {
      name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
      value = "false"
    },
    {
      name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
      value = "false"
    },
    # Resource limits
    {
      name  = "prometheus.prometheusSpec.resources.requests.memory"
      value = "2Gi"
    },
    {
      name  = "prometheus.prometheusSpec.resources.limits.memory"
      value = "4Gi"
    },
    {
      name  = "grafana.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "grafana.resources.limits.memory"
      value = "512Mi"
    },
    # Add Loki datasource
    {
      name  = "grafana.additionalDataSources[0].name"
      value = "Loki"
    },
    {
      name  = "grafana.additionalDataSources[0].type"
      value = "loki"
    },
    {
      name  = "grafana.additionalDataSources[0].uid"
      value = "loki"
    },
    {
      name  = "grafana.additionalDataSources[0].url"
      value = "http://loki.monitoring.svc.cluster.local:3100"
    },
    {
      name  = "grafana.additionalDataSources[0].access"
      value = "proxy"
    },
    {
      name  = "grafana.additionalDataSources[0].isDefault"
      value = "false"
    },
    {
      name  = "grafana.additionalDataSources[0].editable"
      value = "false"
    }
  ]

  depends_on = [
    module.grafana_irsa
  ]
}

# ============================================================================
# Loki Stack (Loki + Fluent Bit)
# ============================================================================

resource "helm_release" "loki_stack" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  namespace        = "monitoring"
  create_namespace = false    # Already created by prometheus stack
  version          = "2.10.3" # Latest stable
  timeout          = 600      # 10 minutes
  wait             = true
  wait_for_jobs    = true

  set = [
    # Enable Loki
    {
      name  = "loki.enabled"
      value = "true"
    },
    # Loki persistence
    {
      name  = "loki.persistence.enabled"
      value = "true"
    },
    {
      name  = "loki.persistence.size"
      value = "20Gi"
    },
    {
      name  = "loki.persistence.storageClassName"
      value = "ebs-gp3"
    },
    # Loki retention
    {
      name  = "loki.config.table_manager.retention_deletes_enabled"
      value = "true"
    },
    {
      name  = "loki.config.table_manager.retention_period"
      value = "168h" # 7 days
    },
    # Enable Fluent Bit for log collection
    {
      name  = "fluent-bit.enabled"
      value = "true"
    },
    # Fluent Bit configuration
    {
      name  = "fluent-bit.config.outputs"
      value = "[OUTPUT]\n    Name loki\n    Match *\n    Host loki.monitoring.svc.cluster.local\n    Port 3100\n    Labels job=fluent-bit\n    Auto_kubernetes_labels on\n    Url /loki/api/v1/push"
    },
    # Disable Promtail (we're using Fluent Bit instead)
    {
      name  = "promtail.enabled"
      value = "false"
    },
    # Disable Grafana (already installed via kube-prometheus-stack)
    {
      name  = "grafana.enabled"
      value = "false"
    },
    # Configure Grafana sidecar datasource (Loki should NOT be default)
    {
      name  = "grafana.sidecar.datasources.isDefaultDatasource"
      value = "false"
    }
  ]

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# ============================================================================
# Grafana Ingress (ALB)
# ============================================================================

resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "monitoring"

    annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}
