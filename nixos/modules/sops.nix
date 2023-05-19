# Without destructering the required module arguments, they will not be provided due to being a lazy attrset.
{
  lib,
  pkgs,
  sources,
  data,
  ...
} @ args:
data.public.sops args (packages: { environment.systemPackages = packages; })
