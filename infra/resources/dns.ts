import * as pulumi from "@pulumi/pulumi";
import { resources, network } from "@pulumi/azure-native";

import { meteorIp, meteorNic } from "./compute";

const dnsResourceGroup = new resources.ResourceGroup("analogcloud-dns", {
    resourceGroupName: "analogcloud-dns",
    location: "WestUS3",
});

const aRecords: {name: string, ips: pulumi.Input<pulumi.Input<string>[]> }[] = [
    { name: "gaia.local", ips: ["192.168.1.1"] },
    { name: "biggs.local", ips: ["192.168.1.101"] },
    { name: "wedge.local", ips: ["192.168.1.102"] },
    { name: "barret.local", ips: ["192.168.1.103"] },
    { name: "cid.local", ips: ["192.168.1.106"] },
    { name: "jessie.local", ips: ["192.168.1.108"] },
    { name: "reno.local", ips: ["192.168.1.110"] },
    { name: "tifa.local", ips: ["192.168.1.109"] },
    { name: "k8s.local", ips: ["192.168.1.3"] },
    { name: "traefik.local", ips: ["192.168.2.91"] },
    { name: "mosquitto.local", ips: ["192.168.2.5"] },
    { name: "meteor", ips: [meteorIp.ipAddress.apply(ip => ip!)] },
    { name: "meteor-01.cloud", ips: [meteorNic.ipConfigurations.apply(ip => ip![0].privateIPAddress!)] },
];

const cnameRecords: {name: string, value: pulumi.Input<string> }[] = [
    { name: "web.local", value: "traefik.local.analogrelay.net." },
    { name: "grafana.local", value: "traefik.local.analogrelay.net." },
    { name: "home.local", value: "traefik.local.analogrelay.net." },
    { name: "plex.local", value: "traefik.local.analogrelay.net." },
];

const analogrelayZone = new network.Zone("zone-analogrelay.net", {
    zoneName: "analogrelay.net",
    resourceGroupName: dnsResourceGroup.name,
    location: "Global",
    zoneType: network.ZoneType.Public,
}, {
    // If the root zone is recreated, the nameservers may change.
    protect: true
});

new network.RecordSet("rs-analogrelay.net-txt", {
    relativeRecordSetName: "@",
    resourceGroupName: dnsResourceGroup.name,
    ttl: 3600,
    zoneName: analogrelayZone.name,
    recordType: "TXT",
    txtRecords: [
        { value: [ "MS=ms25318237" ] },
    ],
})

new network.RecordSet("rs-analogrelay.net-mx", {
    relativeRecordSetName: "@",
    resourceGroupName: dnsResourceGroup.name,
    ttl: 3600,
    zoneName: analogrelayZone.name,
    recordType: "MX",
    mxRecords: [
        { exchange: "gmr-smtp-in.l.google.com.", preference: 5 },
        { exchange: "alt1.gmr-smtp-in.l.google.com.", preference: 10 },
        { exchange: "alt2.gmr-smtp-in.l.google.com.", preference: 20 },
        { exchange: "alt3.gmr-smtp-in.l.google.com.", preference: 30 },
        { exchange: "alt4.gmr-smtp-in.l.google.com.", preference: 40 },
    ]
});

aRecords.forEach(r => {
    new network.RecordSet(`rs-analogrelay.net-a-${r.name}`, {
        resourceGroupName: dnsResourceGroup.name,
        zoneName: analogrelayZone.name,
        relativeRecordSetName: r.name,
        ttl: 3600,
        recordType: "A",
        aRecords: pulumi.output(r.ips).apply(ips => ips.map(ip => {
            return { ipv4Address: ip };
        })),
    });
});

cnameRecords.forEach(r => {
    new network.RecordSet(`rs-analogrelay.net-cname-${r.name}`, {
        resourceGroupName: dnsResourceGroup.name,
        zoneName: analogrelayZone.name,
        relativeRecordSetName: r.name,
        ttl: 3600,
        recordType: "CNAME",
        cnameRecord: {
            cname: r.value,
        },
    });
});