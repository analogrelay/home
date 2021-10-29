using System;
using System.Collections.Generic;
using System.Linq;
using Pulumi;
using Pulumi.AzureNative.Network;
using Pulumi.AzureNative.Network.Inputs;
using Pulumi.AzureNative.Resources;

class HomeStack : Stack
{
    private static List<(string Name, string[] IPs)> LocalARecords = new List<(string, string[])>()
    {
        ("boggs", new[] { "192.168.1.101" }),
        ("wodge", new[] { "192.168.1.102" }),
        ("barret", new[] { "192.168.1.103" }),
        ("cid", new[] { "192.168.1.106" }),
        ("jessie", new[] { "192.168.1.108" }),
        ("reno", new[] { "192.168.1.110" }),
        ("tifa", new[] { "192.168.1.109" }),
        ("k8s", new[] { "192.168.1.102", "192.168.1.103", "192.168.1.108", "192.168.1.109" }),
    };

    private static List<(string Name, string Value)> LocalCnameRecords = new List<(string, string)>() {
        ("grafana", "k8s.local.analogrelay.net."),
        ("home", "k8s.local.analogrelay.net."),
        ("plex", "k8s.local.analogrelay.net."),
    };

    private static List<(string Exchange, int Preference)> MxRecords = new List<(string, int)>() {
        ("gmr-smtp-in.l.google.com.", 5),
        ("alt1.gmr-smtp-in.l.google.com.", 10),
        ("alt2.gmr-smtp-in.l.google.com.", 20),
        ("alt3.gmr-smtp-in.l.google.com.", 30),
        ("alt4.gmr-smtp-in.l.google.com.", 40),
    };

    public HomeStack()
    {
        // Create an Azure Resource Group
        var resourceGroup = new ResourceGroup("stantonnurse-home");

        var root = CreateRootZone(resourceGroup);
        var local = CreateLocalZone(resourceGroup);

        // Create NS record in the root for the local
        new RecordSet("local", new RecordSetArgs()
        {
            RelativeRecordSetName = "local",
            ResourceGroupName = resourceGroup.Name,
            Ttl = 3600,
            ZoneName = root.Name,
            RecordType = "NS",
            NsRecords = local.NameServers.Apply(nses =>
                nses.Select(ns => new NsRecordArgs()
                {
                    Nsdname = ns
                })
            )
        });
    }

    private Zone CreateRootZone(ResourceGroup resourceGroup)
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
            MxRecords = MxRecords.Select((t) => new MxRecordArgs()
            {
                Exchange = t.Exchange,
                Preference = t.Preference,
            }).ToArray()
        });

        return analogRelayZone;
    }

    private Zone CreateLocalZone(ResourceGroup resourceGroup)
    {
        var localZone = new Zone("local.analogrelay.net", new ZoneArgs()
        {
            Location = "Global",
            ResourceGroupName = resourceGroup.Name,
            ZoneName = "local.analogrelay.net",
            ZoneType = ZoneType.Public,
        });

        foreach (var rec in LocalARecords)
        {
            new RecordSet(rec.Name, new RecordSetArgs()
            {
                ResourceGroupName = resourceGroup.Name,
                ZoneName = localZone.Name,
                RelativeRecordSetName = rec.Name,
                Ttl = 3600,
                RecordType = "A",
                ARecords = rec.IPs.Select(a => new ARecordArgs() { Ipv4Address = a }).ToArray(),
            });
        }

        foreach (var rec in LocalCnameRecords)
        {
            new RecordSet(rec.Name, new RecordSetArgs()
            {
                ResourceGroupName = resourceGroup.Name,
                ZoneName = localZone.Name,
                RelativeRecordSetName = rec.Name,
                Ttl = 3600,
                RecordType = "CNAME",
                CnameRecord = new CnameRecordArgs() { Cname = rec.Value }
            });
        }

        return localZone;
    }
}
