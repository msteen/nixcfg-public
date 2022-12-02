{ lib, hostname }:

let
  inherit (lib) hashString mkDefault substring;

in {
  networking.hostName = mkDefault hostname;
  networking.hostId = mkDefault (substring 0 8 (hashString "sha256" hostname));
}
