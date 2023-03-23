{pkgs, nixcfg, ...}:

{
  environment.systemPackages = nixcfg.data.standardPkgs;
}
