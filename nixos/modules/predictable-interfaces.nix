{ config, lib, pkgs, ... }:

let
  macInterfaces = lib.filterAttrs (name: interface: interface.macAddress != null) config.networking.interfaces;
  extraUdevRules = pkgs.writeTextDir "10-mac-network.rules" (lib.concatStrings (lib.mapAttrsToList (name: interface: ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${interface.macAddress}", NAME="${name}"
  '') macInterfaces));

in lib.mkIf (!config.networking.usePredictableInterfaceNames && macInterfaces != {}) {
  boot.kernelParams = [ "net.ifnames=0" "biosdevname=0" ];
  boot.initrd.extraUdevRulesCommands = ''
    cp -v ${extraUdevRules}/*.rules $out/
  '';
}
