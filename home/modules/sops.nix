{
  lib,
  pkgs,
  inputs,
  nixcfgs,
  ...
} @ args:
nixcfgs.public.data.sops args (packages: { home.packages = packages; })
