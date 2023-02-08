job "nodered" {
    datacenters = [ "home0" ]
    type = "service"

    constraint {
        attribute = "${attr.kernel.arch}"
        operator = "!="
        value = "armv7l"
    }

    group "nodered" {
        count = 1

        network {
            port "http" {
                to = "1880"
                host_network = "local"
            }
        }

        service {
            name = "nodered"
            port = "http"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.http.routers.nodered.rule=(Host(`home.analogrelay.net`) || Host(`home.ts.analogrelay.net`)) && PathPrefix(`/nodered`)",
                "traefik.http.routers.nodered.entrypoints=http",
            ]
        }

        volume "nodered-data" {
            type = "host"
            read_only = false
            source = "nodered"
        }

        task "nodered" {
            driver = "docker"
            user = "node-red:2000" # Bit of a hack for volume permissions :(.
            volume_mount {
                volume = "nodered-data"
                destination = "/data"
                read_only = false
            }
            config {
                image = "nodered/node-red:2.2.3"
                ports = [ "http" ]
            }
        }
    }
}