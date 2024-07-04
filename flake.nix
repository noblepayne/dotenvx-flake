{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  outputs = {nixpkgs, ...}: let
    supportedSystems = ["x86_64-linux"]; # TODO: other systems
    systems = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forEachSystem = fn: nixpkgs.lib.mapAttrs fn systems;
  in {
    formatter = forEachSystem (system: pkgs: pkgs.alejandra);
    devShells = forEachSystem (system: pkgs: {
      default = pkgs.mkShell {
        name = "devshell";
        packages = [pkgs.neovim pkgs.nodejs_18];
      };
    });
    packages = forEachSystem (
      system: pkgs: {
        default = pkgs.callPackage ./dotenvx.nix {};
      }
    );
  };
}
