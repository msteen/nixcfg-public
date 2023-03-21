{
  description = "NixOS configuration for what is shareable publicly";

  inputs = {
    nixcfg.url = "github:msteen/nixcfg";
  };

  outputs = inputs: inputs.nixcfg.lib.mkFlake {
    name = "public";
    path = ./.;
    inherit inputs;
  };
}
