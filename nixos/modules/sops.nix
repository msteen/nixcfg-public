{
  lib,
  pkgs,
  inputs,
  nixcfgs,
  ...
} @ args:
nixcfgs.public.data.sops args (packages: { environment.systemPackages = packages; })
