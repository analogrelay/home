import * as path from "path";
import * as fs from "fs";
import * as pulumi from "@pulumi/pulumi";
import { resources, network } from "@pulumi/azure-native";

// We read the Ansible Inventory to get hostname mappings
import * as yaml from "js-yaml";

const TAILNET_DOMAIN = "bicorn-bebop.ts.net";
const inventoryPath = path.resolve(__dirname, "../../inventory.yaml");
const inventory: any = yaml.load(fs.readFileSync(inventoryPath, 'utf-8'));

const inventoryHosts: { [key: string]: { ips: string[], tailnet: boolean } } = {};

function processInventoryGroup(root: any) {
    if (typeof root.hosts === "object") {
        for (const hostName in root.hosts) {
            if (hostName.endsWith(".home.analogrelay.net")) {
                const shortName = hostName.substring(0, hostName.length - ".home.analogrelay.net".length);
                const hostObj = root.hosts[hostName];
                if (hostObj) {
                    let hostCfg = inventoryHosts[shortName] || { ips: [], tailnet: false };
                    inventoryHosts[shortName] = hostCfg;
                    if (hostObj.ansible_host) {
                        hostCfg.ips.push(hostObj.ansible_host);
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

for (const hostName in inventory.all.children.tailnet.hosts) {
    if (hostName.endsWith(".home.analogrelay.net")) {
        const shortName = hostName.substring(0, hostName.length - ".home.analogrelay.net".length);
        if (inventoryHosts[shortName]) {
            inventoryHosts[shortName].tailnet = true;
        }
    }
}

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

const cnameRecords: {name: string, value: pulumi.Input<string> }[] = [];
const serviceHosts = ["traefik", "consul", "nomad", "vault", "influxdb", "grafana", "prometheus"];
serviceHosts.forEach(host => {
    cnameRecords.push({ name: `${host}.home`, value: `home.analogrelay.net.` });
    cnameRecords.push({ name: `${host}.ts`, value: `home.ts.analogrelay.net.` });
});

// Manually "cname" the 'home.analogrelay.net' domain to the front-door node(s).
const loadBalancerHosts = [ "tseng" ];
const loadBalancerIps: string[] = [];
loadBalancerHosts.forEach(host => inventoryHosts[host].ips.forEach(ip => loadBalancerIps.push(ip)));
aRecords.push({ name: "home", ips: loadBalancerIps });

// Manually "cname" the 'home.ts.analogrelay.net' domain to the front-door node(s) tailnet address.
// TODO: Fetch this somehow?
const loadBalancerTsIps = [ "100.120.250.86" ];
aRecords.push({ name: "home.ts", ips: loadBalancerTsIps });

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
        aRecords: pulumi.output(inventoryHosts[n].ips).apply(ips => ips.map(ip => {
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