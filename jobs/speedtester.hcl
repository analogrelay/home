job "speedtester" {
    datacenters = [ "home0" ]
    type = "service"

    constraint {
        attribute = "${attr.kernel.arch}"
        operator = "!="
        value = "armv7l"
    }

    group "speedtester" {
        count = 1
        task "speedtester" {
            vault {
                policies = ["read-kv-telegraf"]
            }

            driver = "docker"
            config {
                image = "telegraf"
                volumes = [
                    "secrets/telegraf.conf:/etc/telegraf/telegraf.conf:ro"
                ]

                # The built-in entry point does some capability shenanigans that we don't need to do.
                entrypoint = [ "/usr/bin/telegraf" ]
            }
            template {
                data = <<EOF
[agent]
    interval = "10s"
    round_interval = true
    metric_batch_size = 1000
    metric_buffer_limit = 10000
    collection_jitter = "0s"
    flush_interval = "10s"
    flush_jitter = "0s"
    precision = "0s"
    omit_hostname = true
[[inputs.internet_speed]]
    interval = "30m"
[[outputs.influxdb_v2]]
    urls = [ "http://influxdb.home.analogrelay.net" ]
    organization = "AnalogHome"
    bucket = "telegraf"
    token = "{{ with secret "kv/data/services/telegraf" }}{{ .Data.data.influx_token }}{{ end }}"
EOF
                destination = "secrets/telegraf.conf"
            }
        }
    }
}