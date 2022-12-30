service {
    id = "hvac-livingroom"
    name = "hvac"
    address = "192.168.0.167"
    port = 80
    check = {
        name = "HTTP API"
        method = "GET"
        http = "http://192.168.0.167"
        interval = "30s"
    }
    tags = [
        "traefik.enable=true",
        "traefik.http.routers.hvaclivingroom.rule=Host(`home.analogrelay.net`) && PathPrefix(`/hvac/livingroom`)",
        "traefik.http.routers.hvaclivingroom.entrypoints=http,https",
        "traefik.http.routers.hvaclivingroom.middlewares=removehvaclivingroomprefix",
        "traefik.http.middlewares.removehvaclivingroomprefix.stripprefix.prefixes=/hvac/livingroom",
    ]
}
