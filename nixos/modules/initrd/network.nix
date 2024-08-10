{ config, lib, pkgs, ... }:

let
  inherit (lib) types;
  cfg = config.networking;
  inherit (config.boot.initrd.network) enable interface;

in {
  options.boot.initrd.network.interface = lib.mkOption {
    type = types.str;
    default = "eth0";
    description = ''
      The ethernet interface to use within the initial ramdisk.
    '';
  };

  config = lib.mkIf ((!cfg.useDHCP || cfg.interfaces ? ${interface} && !(let value = cfg.interfaces.${interface}.useDHCP; in value != null && value)) && !cfg.networkmanager.enable) (lib.mkMerge [
    {
      assertions = lib.singleton {
        assertion = !enable || cfg.defaultGateway != null && cfg.interfaces ? ${interface} && lib.length cfg.interfaces.${interface}.ipv4.addresses > 0;
        message = ''
          To support a static IP address within the initial ramdisk the following things are required:
            1. A default IPv4 gateway
            2. An ethernet interface named ${interface} (as configured via boot.initrd.network.interface)
            3. A static IPv4 address for the above ethernet interface (the first one will be taken)
        '';
      };
    }
    (lib.mkIf enable (with cfg; with (lib.head cfg.interfaces.${interface}.ipv4.addresses);
    let
      netmask = lib.import (pkgs.runCommand "netmask.nix" { } ''
        eval $(${pkgs.busybox}/bin/ipcalc --netmask 127.0.0.1/${toString prefixLength})
        echo '"'"$NETMASK"'"' > "$out"
      '').outPath;
    in {
      # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/chap-anaconda-boot-options#tabl-boot-options-network-formats
      boot.kernelParams = [ "ip=${address}::${defaultGateway.address}:${netmask}:${hostName}:${interface}:none" ];
    }))
  ]);
}
