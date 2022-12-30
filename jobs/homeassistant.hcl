job "homeassistant" {
    datacenters = [ "home0" ]
    type = "service"

    constraint {
        attribute = "${attr.kernel.arch}"
        value = "aarch64"
    }

    group "homeassistant" {
        count = 1

        network {
            port "http" {
                to = "8123"
            }
        }

        service {
            name = "homeassistant"
            port = "http"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.http.routers.homeassistant.rule=Host(`home.analogrelay.net`)",
                "traefik.http.routers.homeassistant.entrypoints=http",
            ]
        }

        volume "homeassistant-data" {
            type = "host"
            read_only = false
            source = "homeassistant"
        }

        task "homeassistant" {
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
        }
    }
}