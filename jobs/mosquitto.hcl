job "mosquitto" {
    datacenters = [ "home0" ]
    type = "service"

    group "mosquitto" {
        count = 1

        network {
            port "mqtt" {
                to = "1883"
            }
            port "mqtt_ws" {
                to = "9001"
            }
        }

        service {
            name = "mosquitto-mqtt"
            port = "mqtt"
            tags = [
                "traefik"
                "traefik.enable=true",
                "traefik.tcp.routers.mosquitto.rule=HostSNI(`*`)",
                "traefik.tcp.routers.mosquitto.entrypoints=mqtt",
                "traefik.tcp.routers.mosquitto.service=mosquitto-mqtt@consulcatalog",
            ]
        }

        service {
            name = "mosquitto-mqtt-ws"
            port = "mqtt_ws"
        }

        volume "mosquitto-data" {
            type = "host"
            read_only = false
            source = "mosquitto"
        }

        task "mosquitto" {
            driver = "docker"
            template {
                data = <<EOH
persistence true
persistence_location /mosquitto/data

listener 1883
protocol mqtt
allow_anonymous true

listener 9001
protocol websockets
allow_anonymous true
EOH
                destination = "local/mosquitto.conf"
            }
            volume_mount {
                volume = "mosquitto-data"
                destination = "/mosquitto/data"
                read_only = false
            }
            config {
                image = "eclipse-mosquitto:2.0.11"
                ports = [ "mqtt", "mqtt_ws" ]
                volumes = [
                    "local/mosquitto.conf:/mosquitto/config/mosquitto.conf"
                ]
            }
        }
    }
}