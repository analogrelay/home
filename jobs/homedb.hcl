job "homedb" {
    datacenters = [ "home0" ]
    type = "service"

    group "homedb" {
        count = 1

        network {
            port "postgres" {
                to = "5432"
                host_network = "local"
            }
        }

        service {
            name = "homedb"
            port = "postgres"
            tags = [
                "traefik",
                "traefik.enable=true",
                "traefik.tcp.routers.homedb.rule=HostSNI(`*`)",
                "traefik.tcp.routers.homedb.entrypoints=postgres",
                "traefik.tcp.routers.homedb.service=homedb@consulcatalog",
                "traefik.tcp.routers.homedb.tls=false",
            ]
        }

        volume "homedb-data" {
            type = "host"
            read_only = false
            source = "homedb"
        }

        task "homedb" {
            vault {
                policies = ["read-kv-homedb"]
            }

            driver = "docker"
            env {
                POSTGRES_USER = "postgres"
                POSTGRES_DB = "postgres"
                PGDATA = "/storage/postgres"
            }
            volume_mount {
                volume = "homedb-data"
                destination = "/storage"
                read_only = false
            }
            config {
                image = "timescale/timescaledb:latest-pg15"
                ports = [ "postgres" ]
                mount {
                    type = "bind"
                    source = "secrets/initdb"
                    target = "/docker-entrypoint-initdb.d"
                }
            }
            template {
  data = <<EOH
POSTGRES_PASSWORD={{ with secret "kv/data/services/homedb/users/postgres" }}{{ .Data.data.password }}{{ end }}
EOH

                destination = "secrets/.env"
                env = true
            }
            template {
                data = <<EOH
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
    CREATE USER ashley WITH LOGIN SUPERUSER PASSWORD '{{ with secret "kv/data/services/homedb/users/ashley" }}{{ .Data.data.password }}{{ end }}';
    CREATE USER homeassistant WITH LOGIN PASSWORD '{{ with secret "kv/data/services/homedb/users/homeassistant" }}{{ .Data.data.password }}{{ end }}';
    CREATE DATABASE homeassistant;
    GRANT ALL PRIVILEGES ON DATABASE homeassistant TO homeassistant;
EOSQL
EOH
                destination = "secrets/initdb/01-setup.sh"
            }
        }
    }
}