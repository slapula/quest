provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "rearc-quest-tfstate"
    key            = "kubernetes/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "rearcquest"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_deployment" "quest" {
  metadata {
    name = "rearc-quest"
    labels = {
      app = "quest"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "quest"
      }
    }

    template {
      metadata {
        labels = {
          app = "quest"
        }
      }

      spec {
        container {
          image = "910243503085.dkr.ecr.us-east-1.amazonaws.com/rearc/quest"
          name  = "quest"

          env {
            name  = "SECRET_WORD"
            value = "TwelveFactor"
          }

          port {
            container_port = 3000
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 3000
            }

            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "quest" {
  metadata {
    name = "rearc-quest"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "https"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "arn:aws:acm:us-east-1:910243503085:certificate/39c7a471-03be-4c33-9e3d-32c1309d3bbc"
    }
  }
  spec {
    selector = {
      app = kubernetes_deployment.quest.metadata.0.labels.app
    }
    port {
      name        = "http"
      port        = 80
      target_port = 3000
    }
    port {
      name        = "https"
      port        = 443
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}

# Create a local variable for the load balancer name.
locals {
  lb_name = split("-", split(".", kubernetes_service.quest.status.0.load_balancer.0.ingress.0.hostname).0).0
}

# Read information about the load balancer using the AWS provider.
data "aws_elb" "quest_lb" {
  name = local.lb_name
}

output "load_balancer_name" {
  value = local.lb_name
}

output "load_balancer_hostname" {
  value = kubernetes_service.quest.status.0.load_balancer.0.ingress.0.hostname
}

output "load_balancer_info" {
  value = data.aws_elb.quest_lb
}