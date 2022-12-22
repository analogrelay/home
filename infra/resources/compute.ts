import * as fs from "fs/promises";
import * as tls from "@pulumi/tls";
import { resources, keyvault, network, compute } from "@pulumi/azure-native";

import * as directory from "./directory";

const computeResourceGroup = new resources.ResourceGroup("analogcloud-compute", {
    resourceGroupName: "analogcloud-compute",
    location: "WestUS3",
});

const vault = new keyvault.Vault("vault-compute", {
    resourceGroupName: computeResourceGroup.name,
    properties: {
        tenantId: directory.tenantId,
        sku: {
            family: keyvault.SkuFamily.A,
            name: keyvault.SkuName.Standard,
        },
        accessPolicies: [
            {
                objectId: directory.andrew.then(a => a.objectId),
                tenantId: directory.tenantId,
                permissions: {
                    keys: ["Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey"],
                    secrets: ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"],
                    certificates: ["Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update"],
                },
            }
        ]
    }
});

new keyvault.Secret("secret-compute-ssh-public", {
    secretName: "Compute-AdminSSH-PublicKey",
    resourceGroupName: computeResourceGroup.name,
    vaultName: vault.name,
    properties: {
        value: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDXw744SbN4l1exPX2TShnbrk/I7GJH5Ku8ebdg8qiAn",
    },
});

const vnet = new network.VirtualNetwork("vnet-compute", {
    resourceGroupName: computeResourceGroup.name,
    addressSpace: {
        addressPrefixes: ["10.0.0.0/16"],
    },
}, {
    ignoreChanges: ["subnets"],
});

const vmSubnet = new network.Subnet("subnet-meteor-vms", {
    resourceGroupName: computeResourceGroup.name,
    virtualNetworkName: vnet.name,
    addressPrefix: "10.0.1.0/24",
});

export const meteorIp = new network.PublicIPAddress("ip-meteor-01", {
    resourceGroupName: computeResourceGroup.name,
    publicIPAllocationMethod: network.IPAllocationMethod.Static,
    dnsSettings: {
        domainNameLabel: "meteor-01",
    },
});

export const nsg = new network.NetworkSecurityGroup("nsg-meteor", {
    resourceGroupName: computeResourceGroup.name,
    securityRules: [
        {
            name: "Tailscale",
            description: "Allow access from Tailscale",
            access: network.SecurityRuleAccess.Allow,
            direction: network.SecurityRuleDirection.Inbound,
            priority: 1000,
            sourceAddressPrefix: "*",
            sourcePortRange: "*",
            destinationAddressPrefix: "VirtualNetwork",
            destinationPortRange: "41641",
            protocol: "UDP",
        }
    ],
});

export const meteorNic = new network.NetworkInterface("nic-meteor-01", {
    resourceGroupName: computeResourceGroup.name,
    networkSecurityGroup: { id: nsg.id },
    ipConfigurations: [{
        name: "webserveripcfg",
        subnet: { id: vmSubnet.id },
        privateIPAllocationMethod: network.IPAllocationMethod.Static,
        privateIPAddress: "10.0.1.10",
        publicIPAddress: { id: meteorIp.id },
    }],
});

// const vm = new compute.VirtualMachine("vm-meteor-01", {
//     resourceGroupName: computeResourceGroup.name,
//     hardwareProfile: {
//         vmSize: "Standard_D2as_v5",
//     },
//     networkProfile: {
//         networkInterfaces: [{
//             id: meteorNic.id,
//             primary: true,
//         }],
//     },
//     identity: {
//         type: compute.ResourceIdentityType.SystemAssigned,
//     },
//     osProfile: {
//         adminUsername: "meteoradmin",
//         computerName: "meteor-01",
//         linuxConfiguration: {
//             ssh: {
//                 publicKeys: [{
//                     path: "/home/meteoradmin/.ssh/authorized_keys",
//                     keyData: adminSshKey.publicKeyOpenssh,
//                 }],
//             },
//             disablePasswordAuthentication: true,
//             provisionVMAgent: true,
//         },
//         customData: cloudInit,
//     },
//     storageProfile: {
//         osDisk: {
//             createOption: compute.DiskCreateOption.FromImage,
//             name: "disk-meteor-01",
//         },
//         imageReference: {
//             publisher: "canonical",
//             offer: "0001-com-ubuntu-server-focal",
//             sku: "20_04-lts-gen2",
//             version: "latest",
//         }
//     },
// });

// new compute.VirtualMachineExtension("vmx-meteor-01-aadssh", {
//     resourceGroupName: computeResourceGroup.name,
//     vmName: vm.name,
//     publisher: "Microsoft.Azure.ActiveDirectory",
//     type: "AADSSHLoginForLinux",
//     typeHandlerVersion: "1.0",
//     autoUpgradeMinorVersion: true,
// });