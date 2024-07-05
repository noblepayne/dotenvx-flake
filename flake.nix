{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = ["x86_64-linux"]; # TODO: other systems
    # compute each supportedSystems pkgs once.
    pkgsBySystem = nixpkgs.lib.genAttrs supportedSystems (
      # If using a more sophisticated overlay:
      #  system: import nixpkgs {inherit system; overlays=[self.overlays.default];}
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        # "extend" nixpkgs w/o recomputing nixpkgs
        pkgs // (self.overlays.default pkgs pkgs)
    );
    # forAllPkgs creates an attrset keyed on `system` with values
    # given by calling provided `fn` with that system's `pkgs` as an arg.
    forAllPkgs = fn:
      nixpkgs.lib.mapAttrs (system: pkgs: (fn pkgs)) pkgsBySystem;
  in {
    overlays.default = final: prev: {
      dotenvx = prev.callPackage ./dotenvx.nix {};
    };
    formatter = forAllPkgs (pkgs: pkgs.alejandra);
    packages = forAllPkgs (pkgs: {
      dotenvx = pkgs.dotenvx;
      default = pkgs.dotenvx;
    });
    devShells = forAllPkgs (pkgs: {
      default = pkgs.mkShell {
        name = "devshell";
        packages = [pkgs.dotenvx pkgs.neovim pkgs.nodejs_18];
      };
    });
  };
}
