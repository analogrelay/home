with (import <nixpkgs> {});
mkShell {
    buildInputs = [
        ansible
        nodejs
        pulumi-bin
        vault
        nomad
        consul
        consul-template
        python310Packages.hvac
        jq
    ];
    shellHook = ''
        export HOME_NIX_SHELL=1
        export NOMAD_ADDR=http://jessie.home.analogrelay.net:4646
        export CONSUL_HTTP_ADDR=http://jessie.home.analogrelay.net:8500
        export VAULT_ADDR=http://jessie.home.analogrelay.net:8200
        export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    '';
}