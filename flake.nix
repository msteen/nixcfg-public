{
  description = "NixOS configuration for what is shareable publicly";

  outputs = inputs@{ self, nixcfg }: nixcfg.lib.mkFlake {
    name = "public";
    path = ./.;
    inherit inputs;
  };
}
