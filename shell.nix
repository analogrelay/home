with (import <nixpkgs> {});
mkShell {
    buildInputs = [
        ansible
    ];
}