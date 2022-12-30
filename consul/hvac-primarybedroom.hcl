service {
    id = "hvac-primarybedroom"
    name = "hvac"
    address = "192.168.0.147"
    port = 80
    check = {
        name = "HTTP API"
        method = "GET"
        http = "http://192.168.0.147"
        interval = "30s"
    }
    tags = [
        "traefik.enable=true",
        "traefik.http.routers.hvacprimarybedroom.rule=Host(`home.analogrelay.net`) && PathPrefix(`/hvac/primarybedroom`)",
        "traefik.http.routers.hvacprimarybedroom.entrypoints=http,https",
        "traefik.http.routers.hvacprimarybedroom.middlewares=removehvacprimarybedroomprefix",
        "traefik.http.middlewares.removehvacprimarybedroomprefix.stripprefix.prefixes=/hvac/primarybedroom",
    ]
}
