job "rtl_433" {
    datacenters = [ "home0" ]
    type = "service"

    group "rtl_433" {
        count = 1

        task "rtl_433" {
            driver = "docker"
            config {
                privileged = true
                image = "hertzg/rtl_433:21.05-alpine3"

                volumes = [
                    "local/rtl_433.conf:/etc/rtl_433/rtl_433.conf",
                ]

                mount {
                    type = "bind"
                    target = "/dev/bus/usb"
                    source = "/dev/bus/usb"
                    readonly = false
                }
            }

            resources {
                device "0bda/usb/2838" { }
            }

            template {
                data = <<EOF
frequency 433.92M
frequency 915M
hop_interval 120

output mqtt://home.analogrelay.net:1883,retain=1,devices=rtl_433/devices/T_[type]/M_[model]/S_[subtype]/C_[channel]/[id],events=rtl_433/events[/id],states=rtl_433/states[/id]
output json

report_meta time:unix:usec:utc
report_meta protocol
report_meta level
report_meta noise
report_meta stats
EOF
                destination = "local/rtl_433.conf"
            }
        }
    }
}