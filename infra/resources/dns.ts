import * as path from "path";
import * as fs from "fs";
import * as pulumi from "@pulumi/pulumi";
import { resources, network } from "@pulumi/azure-native";

// We read the Ansible Inventory to get hostname mappings
import * as yaml from "js-yaml";

const inventoryPath = path.resolve(__dirname, "../../inventory.yaml");
const inventory: any = yaml.load(fs.readFileSync(inventoryPath, 'utf-8'));

const inventoryHosts: { [key: string]: string[] } = {};

function processInventoryGroup(root: any) {
    if (typeof root.hosts === "object") {
        for (const hostName in root.hosts) {
            if (hostName.endsWith(".home.analogrelay.net")) {
                const shortName = hostName.split(".")[0];
                const hostObj = root.hosts[hostName];
                if (hostObj) {
                    let ips = inventoryHosts[shortName] || [];
                    inventoryHosts[shortName] = ips;
                    if (hostObj.ansible_host) {
                        ips.push(hostObj.ansible_host);
                    }
                }
            }
        }
    }

    if (typeof root.children === "object") {
        for (const childGroupName in root.children) {
            processInventoryGroup(root.children[childGroupName])
        }
    }
}
processInventoryGroup(inventory.all);

const dnsResourceGroup = new resources.ResourceGroup("analogcloud-dns", {
    resourceGroupName: "analogcloud-dns",
    location: "WestUS3",
});

// Old nodes
const aRecords: {name: string, ips: pulumi.Input<pulumi.Input<string>[]> }[] = [
    { name: "gaia.local", ips: ["192.168.1.1"] },
    { name: "wedge.local", ips: ["192.168.1.102"] },
    { name: "barret.local", ips: ["192.168.1.103"] },
    { name: "cid.local", ips: ["192.168.1.106"] },
    { name: "k8s.local", ips: ["192.168.1.3"] },
    { name: "traefik.local", ips: ["192.168.2.91"] },
];

// Manually "cname" the 'home.analogrelay.net' domain to the front-door node, tifa.
const loadBalancerHost = "tifa";
aRecords.push({ name: "home", ips: inventoryHosts[loadBalancerHost] });

const cnameRecords: {name: string, value: pulumi.Input<string> }[] = [
    { name: "traefik.home", value: "home.analogrelay.net." },
    { name: "consul.home", value: "home.analogrelay.net." },
    { name: "nomad.home", value: "home.analogrelay.net." },
    { name: "vault.home", value: "home.analogrelay.net." },
    { name: "prometheus.home", value: "home.analogrelay.net." },

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

Object.keys(inventoryHosts).forEach(n => {
    new network.RecordSet(`rs-analogrelay.net-a-inv-${n}`, {
        resourceGroupName: dnsResourceGroup.name,
        zoneName: analogrelayZone.name,
        relativeRecordSetName: `${n}.home`,
        ttl: 3600,
        recordType: "A",
        aRecords: pulumi.output(inventoryHosts[n]).apply(ips => ips.map(ip => {
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