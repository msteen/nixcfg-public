{ config, lib, pkgs, ... }:

let
  inherit (lib) types;
  cfg = config.boot.initrd.udev;

in {
  options = {
    boot.initrd.udev = {
      extraRules = lib.mkOption {
        type = types.lines;
        default = "";
        description = ''
          Extra udev rules for in the initial ramdisk.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.extraRules != "") {
    boot.initrd = {
      extraUdevRulesCommands = let extraUdevRules = pkgs.writeTextDir "99-local.rules" cfg.extraRules; in ''
        cp -v ${extraUdevRules}/*.rules $out/
      '';
    };
  };
}
