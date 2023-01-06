job "influxdb" {
    datacenters = [ "home0" ]
    type = "service"

    constraint {
        attribute = "${attr.kernel.arch}"
        value = "x86_64"
    }

    group "influxdb" {
        count = 1

        network {
            port "http" {
                to = "8086"
            }
        }

        service {
            name = "influx"
            port = "http"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.http.routers.influxdb.rule=Host(`influxdb.home.analogrelay.net`)",
                "traefik.http.routers.influxdb.entrypoints=http",
            ]
        }

        volume "influxdb-data" {
            type = "host"
            read_only = false
            source = "influxdb"
        }

        task "influxdb" {
            driver = "docker"
            volume_mount {
                volume = "influxdb-data"
                destination = "/var/lib/influxdb2"
                read_only = false
            }
            config {
                image = "influxdb:2.4"
                ports = [ "http" ]
            }
        }
    }
}