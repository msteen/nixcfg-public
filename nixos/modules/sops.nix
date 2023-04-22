{
  lib,
  pkgs,
  inputs,
  nixcfgs,
  ...
}: let
  inherit (lib) optionalAttrs;
in
  optionalAttrs (inputs ? sops-nix) {
    imports = [
      nixcfgs.public.data.sops
    ];

    config = {
      environment.systemPackages = nixcfgs.public.data.sops-pkgs { inherit pkgs; };
    };
  }
