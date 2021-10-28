using System;
using System.Linq;
using Pulumi;
using Pulumi.AzureNative.Network;
using Pulumi.AzureNative.Network.Inputs;
using Pulumi.AzureNative.Resources;

class HomeStack : Stack
{
    public HomeStack()
    {
        // Create an Azure Resource Group
        var resourceGroup = new ResourceGroup("stantonnurse-home");

        CreateRootZone(resourceGroup);
        CreateLocalZone(resourceGroup);
    }

    private void CreateRootZone(ResourceGroup resourceGroup)
    {
        var analogRelayZone = new Zone("analogrelay.net", new ZoneArgs()
        {
            Location = "Global",
            ResourceGroupName = resourceGroup.Name,
            ZoneName = "analogrelay.net",
            ZoneType = ZoneType.Public,
        });

        var mx = new RecordSet("@", new RecordSetArgs()
        {
            RelativeRecordSetName = "@",
            ResourceGroupName = resourceGroup.Name,
            Ttl = 3600,
            ZoneName = analogRelayZone.Name,
            RecordType = "MX",
            MxRecords = {
                new MxRecordArgs() { Exchange = "gmr-smtp-in.l.google.com.", Preference = 5 },
                new MxRecordArgs() { Exchange = "alt1.gmr-smtp-in.l.google.com.", Preference = 10 },
                new MxRecordArgs() { Exchange = "alt2.gmr-smtp-in.l.google.com.", Preference = 20 },
                new MxRecordArgs() { Exchange = "alt3.gmr-smtp-in.l.google.com.", Preference = 30 },
                new MxRecordArgs() { Exchange = "alt4.gmr-smtp-in.l.google.com.", Preference = 40 },
            }
        });

        var ns = new RecordSet("local", new RecordSetArgs()
        {
            RelativeRecordSetName = "local",
            ResourceGroupName = resourceGroup.Name,
            Ttl = 3600,
            ZoneName = analogRelayZone.Name,
            RecordType = "NS",
            NsRecords = {
                new NsRecordArgs() { Nsdname = "ns1-03.azure-dns.com." },
                new NsRecordArgs() { Nsdname = "ns2-03.azure-dns.net." },
                new NsRecordArgs() { Nsdname = "ns3-03.azure-dns.org." },
                new NsRecordArgs() { Nsdname = "ns4-03.azure-dns.info." },
            }
        });
    }

    private void CreateLocalZone(ResourceGroup resourceGroup)
    {
        var localZone = new Zone("local.analogrelay.net", new ZoneArgs()
        {
            Location = "Global",
            ResourceGroupName = resourceGroup.Name,
            ZoneName = "local.analogrelay.net",
            ZoneType = ZoneType.Public,
        });

        ARecord(localZone, resourceGroup, "biggs", "192.168.1.101");
        ARecord(localZone, resourceGroup, "wedge", "192.168.1.102");
        ARecord(localZone, resourceGroup, "barret", "192.168.1.103");
        ARecord(localZone, resourceGroup, "cid", "192.168.1.106");
        ARecord(localZone, resourceGroup, "jessie", "192.168.1.108");
        ARecord(localZone, resourceGroup, "reno", "192.168.1.110");
        ARecord(localZone, resourceGroup, "tifa", "192.168.1.109");
        ARecord(localZone, resourceGroup, "k8s", "192.168.1.102", "192.168.1.103", "192.168.1.108", "192.168.1.109");

        CnameRecord(localZone, resourceGroup, "grafana", "k8s.local.analogrelay.net.");
        CnameRecord(localZone, resourceGroup, "home", "k8s.local.analogrelay.net.");
        CnameRecord(localZone, resourceGroup, "plex", "k8s.local.analogrelay.net.");
    }

    private void ARecord(Zone zone, ResourceGroup resourceGroup, string name, params string[] addr)
    {
        new RecordSet(name, new RecordSetArgs()
        {
            ResourceGroupName = resourceGroup.Name,
            ZoneName = zone.Name,
            RelativeRecordSetName = name,
            Ttl = 3600,
            RecordType = "A",
            ARecords = addr.Select(a => new ARecordArgs() { Ipv4Address = a }).ToArray(),
        });
    }

    private void CnameRecord(Zone zone, ResourceGroup resourceGroup, string name, string value)
    {
        new RecordSet(name, new RecordSetArgs()
        {
            ResourceGroupName = resourceGroup.Name,
            ZoneName = zone.Name,
            RelativeRecordSetName = name,
            Ttl = 3600,
            RecordType = "CNAME",
            CnameRecord = new CnameRecordArgs() { Cname = value }
        });
    }
}
