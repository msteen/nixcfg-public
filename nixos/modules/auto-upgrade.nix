{ nixcfg, ... }: {
  system.autoUpgrade = {
    persistent = true;
    operation = "switch";
    flake = "git+file://" + toString nixcfg.path;
  };
}
