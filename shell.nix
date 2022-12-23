with (import <nixpkgs> {});
mkShell {
    buildInputs = [
        ansible
        nodejs
        pulumi-bin
    ];
}