{ config, lib, pkgs, ... }:

with lib;

let
  macInterfaces = filterAttrs (name: interface: interface.macAddress != null) config.networking.interfaces;
  extraUdevRules = pkgs.writeTextDir "10-mac-network.rules" (concatStrings (mapAttrsToList (name: interface: ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${interface.macAddress}", NAME="${name}"
  '') macInterfaces));

in mkIf (!config.networking.usePredictableInterfaceNames && macInterfaces != {}) {
  boot.kernelParams = [ "net.ifnames=0" "biosdevname=0" ];
  boot.initrd.extraUdevRulesCommands = ''
    cp -v ${extraUdevRules}/*.rules $out/
  '';
}
