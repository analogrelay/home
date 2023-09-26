job "homeassistant" {
    datacenters = [ "home0" ]
    type = "service"

    constraint {
        attribute = "${attr.kernel.arch}"
        operator = "!="
        value = "armv7l"
    }

    group "homeassistant" {
        count = 1

        network {
            port "http" {
                to = "8123"
                host_network = "local"
            }
        }

        service {
            name = "homeassistant"
            port = "http"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.http.routers.homeassistant.rule=Host(`home.analogrelay.net`) || Host(`home.ts.analogrelay.net`)",
                "traefik.http.routers.homeassistant.entrypoints=http",
            ]
        }

        volume "homeassistant-data" {
            type = "host"
            read_only = false
            source = "homeassistant"
        }

        task "homeassistant" {
            vault {
                policies = ["read-kv-homedb", "read-kv-homeassistant"]
            }

            driver = "docker"
            env {
                TZ = "America/Vancouver"
            }
            volume_mount {
                volume = "homeassistant-data"
                destination = "/config"
                read_only = false
            }
            config {
                image = "homeassistant/home-assistant:2022.12"
                ports = [ "http" ]
            }
            resources {
                cpu = 100
                memory = 600
            }
            template {
                data = <<EOH
RECORDER_DB_URL=postgresql://homeassistant:{{ with secret "kv/data/services/homedb/users/homeassistant" }}{{ .Data.data.password }}{{ end }}@home.analogrelay.net/homeassistant
INFLUX_TOKEN={{ with secret "kv/data/services/homeassistant" }}{{ .Data.data.influx_token }}{{ end }}
EOH
                destination = "secrets/.env"
                env = true
            }
        }
    }
}