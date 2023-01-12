job "prometheus" {
    datacenters = ["home0"]

    group "prometheus" {
        network {
            port "http" {
                to = "9090"
                host_network = "local"
            }
        }
        service {
            name = "prometheus"
            port = "http"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.http.routers.prometheus.rule=Host(`prometheus.home.analogrelay.net`) || Host(`prometheus.ts.analogrelay.net`)",
                "traefik.http.routers.prometheus.entrypoints=http",
            ]
        }

        volume "prometheus-data" {
            type = "host"
            read_only = false
            source = "prometheus"
        }

        task "prometheus" {
            driver = "docker"
            config {
                image = "prom/prometheus:v2.41.0"
                ports = ["http"]

                volumes = [
                    "local/prometheus.yml:/etc/prometheus/prometheus.yml",
                ]
            }

            vault {
                policies = ["read-kv-prometheus"]
            }

            volume_mount {
                volume = "prometheus-data"
                destination = "/prometheus"
                read_only = false
            }

            template {
                data = <<EOH
global:
    scrape_interval: 15s
    evaluation_interval: 15s
scrape_configs:
    - job_name: nodes
      consul_sd_configs:
        - server: "172.17.0.1:8500"
          services:
            - 'node-exporter'
      relabel_configs:
        - source_labels: [__meta_consul_node]
          target_label: instance
          replacement: "$${1}.home.analogrelay.net"
        - source_labels: [__meta_consul_dc]
          target_label: datacenter
        - source_labels: [__meta_consul_service]
          target_label: consul_service
    - job_name: nomads
      metrics_path: /v1/metrics
      params:
        format: ['prometheus']
      consul_sd_configs:
        - server: "172.17.0.1:8500"
          tags: [ 'http' ]
          services: ['nomad', 'nomad-client' ]
      relabel_configs:
        - source_labels: [__meta_consul_node]
          target_label: instance
          replacement: "$${1}.home.analogrelay.net"
        - source_labels: [__meta_consul_dc]
          target_label: datacenter
        - source_labels: [__meta_consul_service]
          target_label: consul_service
    - job_name: homeassistant
      metrics_path: /api/prometheus
      authorization:
        credentials: "{{with secret "kv/data/services/prometheus/homeassistant"}}{{.Data.data.token}}{{end}}"
      consul_sd_configs:
        - server: "172.17.0.1:8500"
          services: [ 'homeassistant' ]
      relabel_configs:
        - source_labels: [__meta_consul_node]
          target_label: instance
          replacement: "$${1}.home.analogrelay.net"
        - source_labels: [__meta_consul_dc]
          target_label: datacenter
        - source_labels: [__meta_consul_service]
          target_label: consul_service
EOH
                destination = "local/prometheus.yml"
            }
        }
    }
}