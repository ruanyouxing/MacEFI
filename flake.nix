{
  description = "MacEFI - Hackintosh EFI with rEFInd + OpenCore";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

    catppuccinRefind = system: let
      pkgs = import nixpkgs { inherit system; };
    in pkgs.fetchzip {
      url = "https://github.com/catppuccin/refind/archive/main.tar.gz";
      sha256 = "1z252rfzsx8k8pkygbknicdrl9z2j5ibkd9qx1m7r9w4yn98r3yz";
    };

    macefiPkg = system: let
      pkgs = import nixpkgs { inherit system; };
      theme = catppuccinRefind system;
    in pkgs.stdenvNoCC.mkDerivation {
      name = "macefi";
      src = ./.;
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out
        cp -r $src/BOOT $out/
        cp -r $src/OC $out/
        [ -d "$src/tools" ] && cp -r $src/tools $out/ || true

        # Add Catppuccin rEFInd theme (all flavors)
        mkdir -p $out/BOOT/themes/catppuccin
        cp -r ${theme}/assets $out/BOOT/themes/catppuccin/assets/
        cp ${theme}/*.conf $out/BOOT/themes/catppuccin/
      '';
    };
  in {
    packages = forAllSystems (system: {
      default = macefiPkg system;
      macefi = macefiPkg system;
    });

    nixosModules.default = { pkgs, config, lib, ... }: let
      cfg = config.services.macefi;
      efiMountPoint = config.boot.loader.efi.efiSysMountPoint;

      macefiPkgDerivation =
        self.packages.${pkgs.stdenv.hostPlatform.system}.default;

      catppuccinThemeConf = pkgs.writeText "catppuccin-theme.conf" ''
        hideui singleuser,hints,arrows,label,badges,safemode,hwtest
        use_graphics_for osx,linux,elilo,grub,windows
        icons_dir themes/catppuccin/assets/${cfg.catppuccinFlavor}/icons
        banner themes/catppuccin/assets/${cfg.catppuccinFlavor}/background.png
        banner_scale fillscreen
        selection_big   themes/catppuccin/assets/${cfg.catppuccinFlavor}/selection_big.png
        selection_small themes/catppuccin/assets/${cfg.catppuccinFlavor}/selection_small.png
        showtools shutdown
      '';

      macefiSyncScript = pkgs.writeScriptBin "macefi-sync" ''
        #!${pkgs.runtimeShell}
        EFI_MOUNT="${efiMountPoint}"
        MACEFI_PKG="${macefiPkgDerivation}"
        CATPPUCCIN_THEME_CONF="${catppuccinThemeConf}"
        ${builtins.readFile ./scripts/macefi-sync.sh}
      '';

      macefiBootEntryScript = pkgs.writeScriptBin "macefi-boot-entry" ''
        #!${pkgs.runtimeShell}
        EFI_MOUNT="${efiMountPoint}"
        EFIBOOTMGR="${pkgs.efibootmgr}/bin/efibootmgr"
        ${builtins.readFile ./scripts/macefi-boot-entry.sh}
      '';
    in {
      options.services.macefi = {
        catppuccinFlavor = lib.mkOption {
          type = lib.types.enum ["latte" "frappe" "macchiato" "mocha"];
          default = "mocha";
          description = "Catppuccin flavor for the rEFInd theme";
        };
      };

      config = {
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
  };
}
