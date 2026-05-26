{
  description = "MacEFI - Hackintosh EFI with rEFInd + OpenCore";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
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

    nixosModules.default = { pkgs, config, lib, ... }: let
      efiMountPoint = config.boot.loader.efi.efiSysMountPoint;

      macefiPkg =
        self.packages.${pkgs.stdenv.hostPlatform.system}.default;

      macefiSyncScript = pkgs.writeScriptBin "macefi-sync" ''
        #!${pkgs.runtimeShell}
        EFI_MOUNT="${efiMountPoint}"
        MACEFI_PKG="${macefiPkg}"
        ${builtins.readFile ./scripts/macefi-sync.sh}
      '';

      macefiBootEntryScript = pkgs.writeScriptBin "macefi-boot-entry" ''
        #!${pkgs.runtimeShell}
        EFI_MOUNT="${efiMountPoint}"
        EFIBOOTMGR="${pkgs.efibootmgr}/bin/efibootmgr"
        ${builtins.readFile ./scripts/macefi-boot-entry.sh}
      '';
    in {
      boot.loader.efi.canTouchEfiVariables = lib.mkForce true;
      boot.loader.grub.efiInstallAsRemovable = lib.mkForce false;

      environment.systemPackages = with pkgs; [
        efibootmgr
        macefiSyncScript
        macefiBootEntryScript
      ];

      systemd.services.macefi-sync = {
        description =
          "Sync MacEFI files to EFI partition (run manually with: systemctl start macefi-sync)";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${macefiSyncScript}/bin/macefi-sync";
          RemainAfterExit = true;
        };
      };

      systemd.services.macefi-boot-entry = {
        description =
          "Create and prioritize MacEFI rEFInd boot entry (run manually with: systemctl start macefi-boot-entry)";
        requires = ["macefi-sync.service"];
        after = ["macefi-sync.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${macefiBootEntryScript}/bin/macefi-boot-entry";
          RemainAfterExit = true;
        };
      };
    };
  };
}
