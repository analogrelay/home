job "zwavejs2mqtt" {
    datacenters = [ "home0" ]
    type = "service"

    group "zwavejs2mqtt" {
        count = 1

        network {
            port "http" {
                to = "8091"
            }
            port "ws" {
                to = "3000"
            }
        }

        service {
            name = "zwavejs2mqtt"
            port = "http"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.http.routers.zwavejs2mqtt.rule=Host(`home.analogrelay.net`) && PathPrefix(`/zwave`)",
                "traefik.http.routers.zwavejs2mqtt.entrypoints=http",
                "traefik.http.routers.zwavejs2mqtt.middlewares=stripzwaveprefix,addzwaveheader",
                "traefik.http.middlewares.stripzwaveprefix.stripprefix.prefixes=/zwave",
                "traefik.http.middlewares.addzwaveheader.headers.customrequestheaders.X-External-Path=/zwave",
            ]
        }

        service {
            name = "zwavejs2mqtt-ws"
            port = "ws"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.http.routers.zwavejs2mqttws.rule=Host(`home.analogrelay.net`) && PathPrefix(`/zwave/ws`)",
                "traefik.http.routers.zwavejs2mqttws.entrypoints=http",
                "traefik.http.routers.zwavejs2mqttws.middlewares=stripzwavewsprefix",
                "traefik.http.middlewares.stripzwavewsprefix.stripprefix.prefixes=/zwave/ws",
            ]
        }

        volume "zwavejs2mqtt-data" {
            type = "host"
            read_only = false
            source = "zwavejs2mqtt"
        }

        task "zwavejs2mqtt" {
            driver = "docker"
            config {
                privileged = true
                image = "zwavejs/zwavejs2mqtt:8"
                ports = [ "http", "ws" ]

                mount {
                    type = "bind"
                    source = "/dev/ttyACM0"
                    target = "/dev/zwave"
                    readonly = false
                }
            }

            volume_mount {
                volume = "zwavejs2mqtt-data"
                destination = "/usr/src/app/store"
                read_only = false
            }

            resources {
                device "0658/usb/0200" { }
            }
        }
    }
}