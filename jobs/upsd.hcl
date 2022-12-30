job "upsd" {
    datacenters = [ "home0" ]
    type = "service"

    group "upsd" {
        count = 1

        network {
            port "upsd" {
                to = "3493"
            }
        }

        service {
            name = "upsd"
            port = "upsd"
        }

        task "upsd" {
            driver = "docker"
            config {
                privileged = true
                image = "instantlinux/nut-upsd:2.8.0-r4"
                ports = [ "upsd" ]
            }

            env {
                API_PASSWORD = "V4PsDEn9YXJqhHh3ubW2"
            }

            resources {
                device "051d/usb/0002" { }
            }
        }
    }
}