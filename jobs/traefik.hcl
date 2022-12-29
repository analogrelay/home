job "traefik" {
    datacenters = [ "home0" ]
    type = "service"

    group "traefik" {
        count = 1

        network {
            port "http" {
                static = "80"
                to = "80"
            }
            port "https" {
                static = "443"
                to = "443"
            }
            port "mqtt" {
                static = "1883"
                to = "1883"
            }
            port "mqtt_ws" {
                static = "9001"
                to = "9001"
            }
        }

        service {
            name = "traefik-http"
            port = "http"
        }

        service {
            name = "traefik-https"
            port = "https"
        }

        service {
            name = "traefik-mqtt"
            port = "mqtt"
        }

        service {
            name = "traefik-mqtt-ws"
            port = "mqtt_ws"
        }

        task "traefik" {
            driver = "docker"
            config {
                image = "traefik:v2.9"
                ports = [ "http", "https", "mqtt", "mqtt_ws" ]

                volumes = [
                    "local/traefik.toml:/etc/traefik/traefik.toml"
                ]
            }

            template {
                data = <<EOF
api:
    dashboard: true
http:
    routers:
        dashboard:
            rule: Host(`traefik.home.analogrelay.net`)
            service: api@internal
providers:
    consul:
        rootKey: "traefik"
        endpoints:
            - "127.0.0.1:8500"
EOF
                destination = "local/traefik.toml"
            }
        }
    }
}