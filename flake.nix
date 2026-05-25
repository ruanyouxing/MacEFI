{
  description = "MacEFI - Hackintosh EFI with rEFInd + OpenCore";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.stdenvNoCC.mkDerivation {
        name = "macefi";
        src = ./.;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out
          cp -r $src/BOOT $out/
          cp -r $src/OC $out/
          [ -d "$src/tools" ] && cp -r $src/tools $out/ || true
        '';
      };
      macefi = self.packages.${system}.default;
    });
  };
}
