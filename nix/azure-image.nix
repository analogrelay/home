{ pkgs ? import <nixpkgs> { } }:
let config = {
  imports = [ <nixpkgs/nixos/modules/virtualisation/azure-image.nix> ];
};
in
(pkgs.nixos config).azureImage