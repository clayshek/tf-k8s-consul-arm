# Terraform Kubernetes provisioner for Consul on ARM (Raspberry Pi).
# Uses Custom Kubernetes TF Provider from https://github.com/sl1pm4t/terraform-provider-kubernetes
# Change this to Terraform standard provider when StatefulSet is supported. 
# See https://github.com/terraform-providers/terraform-provider-kubernetes/issues/3
# Resources provisioned: Service, Persistent Volume, StatefulSet

# Provider setup: https://www.terraform.io/docs/providers/kubernetes/guides/getting-started.html#provider-setup
provider "kubernetes" {}

# CLUSTERIP SERVICE RESOURCE CONFIG
resource "kubernetes_service" "consul" {
  metadata {
    name = "consul"

    labels {
      name = "consul"
    }
  }

  spec {
    selector {
      app = "consul"
    }

    type       = "ClusterIP"
    cluster_ip = "None"

    port {
      name        = "server"
      port        = 8300
      target_port = 8300
    }

    port {
      name        = "serflan-tcp"
      port        = 8301
      target_port = 8301
      protocol    = "TCP"
    }

    port {
      name        = "serflan-udp"
      port        = 8301
      target_port = 8301
      protocol    = "UDP"
    }

    port {
      name        = "serfwan-tcp"
      port        = 8302
      target_port = 8302
      protocol    = "TCP"
    }

    port {
      name        = "serfwan-udp"
      port        = 8302
      target_port = 8302
      protocol    = "UDP"
    }

    port {
      name        = "http"
      port        = 8500
      target_port = 8500
    }

    port {
      name        = "consuldns-tcp"
      port        = 8600
      target_port = 8600
      protocol    = "TCP"
    }

    port {
      name        = "consuldns-udp"
      port        = 8600
      target_port = 8600
      protocol    = "UDP"
    }
  }
}

# NODEPORT SERVICE RESOURCE CONFIG
resource "kubernetes_service" "consul-nodeport-svc" {
  metadata {
    name = "consul-nodeport-svc"
  }

  spec {
    selector {
      app = "consul"
    }

    type = "NodePort"

    port {
      name      = "server"
      port      = 8300
      node_port = 30300
      protocol  = "TCP"
    }

    port {
      name      = "serflan-tcp"
      port      = 8301
      node_port = 30301
      protocol  = "TCP"
    }

    port {
      name      = "serflan-udp"
      port      = 8301
      node_port = 30301
      protocol  = "UDP"
    }

    port {
      name      = "serfwan-tcp"
      port      = 8302
      node_port = 30302
      protocol  = "TCP"
    }

    port {
      name      = "serfwan-udp"
      port      = 8302
      node_port = 30302
      protocol  = "UDP"
    }

    port {
      name      = "http"
      port      = 8500
      node_port = 30500
    }

    port {
      name      = "consuldns-tcp"
      port      = 8600
      node_port = 30600
      protocol  = "TCP"
    }

    port {
      name      = "consuldns-udp"
      port      = 8600
      node_port = 30600
      protocol  = "UDP"
    }
  }
}

# PERSISTENT VOLUME RESOURCE CONFIG
# Coded here for NFS, but can be modified for other supported K8s persistent volume types.
# See https://www.terraform.io/docs/providers/kubernetes/r/persistent_volume.html

resource "kubernetes_persistent_volume" "consul-pv" {
  count = "${var.consul_count}"

  metadata {
    name = "consul-${count.index}-pv"
  }

  spec {
    capacity {
      storage = "${var.storage_capacity}"
    }

    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "consul"

    persistent_volume_source {
      nfs {
        path      = "${var.vol_path}${count.index}"
        server    = "${var.nfs_server}"
        read_only = "false"
      }
    }
  }
}

# STATEFUL SET RESOURCE CONFIG 
# Based off of https://github.com/kelseyhightower/consul-on-kubernetes

resource "kubernetes_stateful_set" "consul" {
  metadata {
    name = "consul"
  }

  spec {
    selector {
      app = "consul"
    }

    service_name = "consul"
    replicas     = "${var.consul_count}"

    volume_claim_templates {
      metadata {
        name = "data"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests {
            storage = "${var.storage_capacity}"
          }
        }

        storage_class_name = "consul"
      }
    }

    template {
      metadata {
        labels {
          app = "consul"
        }
      }

      spec {
        security_context {
          fs_group = "1000"
        }

        termination_grace_period_seconds = "10"

        container {
          name  = "consul"
          image = "${var.image_name}"

          env {
            name = "POD_IP"

            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name = "NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          /* Code block for setting encryption key env var from secret, not using this yet
          env {
            name = "GOSSIP_ENCRYPTION_KEY"
            value_from {
              secret_key_ref {
                name = "consul"
                key  = "gossip-encryption-key"
            }
          }
*/

          args = ["agent", "-advertise=$(POD_IP)", "-bind=0.0.0.0", "-bootstrap-expect=3",
            "-retry-join=consul-0.consul.$(NAMESPACE).svc.cluster.local",
            "-retry-join=consul-1.consul.$(NAMESPACE).svc.cluster.local",
            "-retry-join=consul-2.consul.$(NAMESPACE).svc.cluster.local",
            "-client=0.0.0.0",
            "-datacenter=dc1",
            "-data-dir=/consul/data",
            "-domain=cluster.local",
            "-server",
            "-ui",
            "-disable-host-node-id",
          ]
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "consul leave"]
              }
            }
          }
          port {
            name           = "server"
            container_port = 8300
          }
          port {
            name           = "serflan"
            container_port = 8301
          }
          port {
            name           = "serfwan"
            container_port = 8302
          }
          port {
            name           = "ui-port"
            container_port = 8500
          }
          port {
            name           = "consuldns"
            container_port = 8600
          }
          volume_mount {
            name       = "data"
            mount_path = "/consul/data"
          }
          volume_mount {
            name       = "config"
            mount_path = "/consul/config"
          }
          volume_mount {
            name       = "tls"
            mount_path = "/etc/tls"
          }
        }

        volume {
          name = "config"
        }

        volume {
          name = "tls"
        }
      }
    }
  }
}
