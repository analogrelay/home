job "traefik" {
    datacenters = [ "home0" ]
    type = "service"

    constraint {
        attribute = "${node.unique.name}"
        value = "tseng.node"
    }

    group "traefik" {
        count = 1

        network {
            port "http" {
                static = "80"
                to = "80"
                host_network = "local"
            }
            port "https" {
                static = "443"
                to = "443"
                host_network = "local"
            }
            port "tailnet-http" {
                static = "80"
                to = "80"
                host_network = "tailnet"
            }
            port "tailnet-https" {
                static = "443"
                to = "443"
                host_network = "tailnet"
            }
            port "mqtt" {
                static = "1883"
                to = "1883"
                host_network = "local"
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

        task "traefik" {
            driver = "docker"
            config {
                image = "traefik:v2.9"
                ports = [ "http", "https", "mqtt", "tailnet-http", "tailnet-https" ]

                volumes = [
                    "local/traefik.yaml:/etc/traefik/traefik.yaml",
                    "local/conf.d:/etc/traefik/conf.d"
                ]
            }

            resources {
                memory = 100
            }

            template {
                data = <<EOF
ping:
    entryPoint: http
api:
    dashboard: true
entryPoints:
    http:
        address: ":80"
    https:
        address: ":443"
    mqtt:
        address: ":1883"
providers:
    file:
        directory: "/etc/traefik/conf.d"
    consulCatalog:
        refreshInterval: 30s
        exposedByDefault: false
        endpoint:
            address: "172.17.0.1:8500"
EOF
                destination = "local/traefik.yaml"
            }

            template {
                data = <<EOF
http:
    routers:
        traefik_redirect:
            entrypoints:
                - "http"
                - "https"
            rule: "(Host(`traefik.home.analogrelay.net`) || Host(`traefik.ts.analogrelay.net`))"
            service: api@internal
            middlewares:
                - "traefikRedirect"
        traefik_dashboard:
            entrypoints:
                - "http"
                - "https"
            rule: "(Host(`traefik.home.analogrelay.net`) || Host(`traefik.ts.analogrelay.net`)) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"
            service: api@internal
        {{ if gt (service "consul" | len ) 0 }}
        consul_dashboard:
            entrypoints:
                - "http"
                - "https"
            rule: "Host(`consul.home.analogrelay.net`) || Host(`consul.ts.analogrelay.net`)"
            service: consul
        {{ end }}
        {{ if gt (service "http.nomad" | len ) 0 }}
        nomad_dashboard:
            entrypoints:
                - "http"
                - "https"
            rule: "Host(`nomad.home.analogrelay.net`) || Host(`nomad.ts.analogrelay.net`)"
            service: nomad
        {{ end }}
        {{ if gt (service "vault" | len ) 0 }}
        vault_dashboard:
            entrypoints:
                - "http"
                - "https"
            rule: "Host(`vault.home.analogrelay.net`) || Host(`vault.ts.analogrelay.net`)"
            service: vault
        {{ end }}
    services:
        {{ if gt (service "consul" | len ) 0 }}
        consul:
            loadBalancer:
                servers:{{ range service "consul" }}
                    - url: "http://{{ .Address }}:8500"{{ end }}
        {{ end }}
        {{ if gt (service "vault" | len ) 0 }}
        vault:
            loadBalancer:
                servers:{{ range service "vault" }}
                    - url: "http://{{ .Address }}:8200"{{ end }}
        {{ end }}
        {{ if gt (service "http.nomad" | len ) 0 }}
        nomad:
            loadBalancer:
                servers:{{ range service "http.nomad" }}
                    - url: "http://{{ .Address }}:4646"{{ end }}
        {{ end }}
    middlewares:
        traefikRedirect:
            redirectRegex:
                regex: "^https?://traefik.home.analogrelay.net$"
                replacement: "https://traefik.home.analogrelay.net/dashboard/"

EOF
                destination = "local/conf.d/dashboard.yaml"
            }
        }
    }
}