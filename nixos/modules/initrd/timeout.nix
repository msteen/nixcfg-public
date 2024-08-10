{ config, lib, pkgs, ... }:

let
  cfg = config.boot.initrd;

in {
  options.boot.initrd.timeout = with types; lib.mkOption {
    type = int;
    default = 0;
    description = ''
      How many seconds should have passed before the machine is powered off (0 means disabled).
    '';
  };

  config = lib.mkIf (cfg.timeout > 0) {
    boot.initrd.network.postCommands = ''
    (
      echo 'timeout> timer started'
      sleep ${toString cfg.timeout}
      echo 'timeout> timer finished'
      sysrq-poweroff
    ) &
    '';
  };
}
