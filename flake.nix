{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = ["x86_64-linux"]; # TODO: other systems
    forAllSystems = fn:
      nixpkgs.lib.mapAttrs
      (system: pkgs: fn pkgs)
      (nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages);
  in {
    formatter = forAllSystems (pkgs: pkgs.alejandra);
    overlays.default = final: prev: {
      dotenvx = prev.callPackage ./dotenvx.nix {};
    };
    packages = forAllSystems (pkgs: let
      overlayPkgs = self.overlays.default pkgs pkgs;
    in {
      dotenvx = overlayPkgs.dotenvx;
      default = overlayPkgs.dotenvx;
    });
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "devshell";
        packages = [
          self.packages.${pkgs.system}.dotenvx
          pkgs.neovim
          pkgs.nodejs_18
        ];
      };
    });
  };
}
