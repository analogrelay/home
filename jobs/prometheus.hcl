job "prometheus" {
    datacenters = ["home0"]

    group "prometheus" {
        network {
            port "http" {
                to = "9090"
            }
        }
        service {
            name = "prometheus"
            port = "http"
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
    - job_name: node_exporter
      consul_sd_configs:
        - server: "172.17.0.1:8500"
          services:
            - 'node-exporter'
EOH
                destination = "local/prometheus.yml"
            }
        }
    }
}