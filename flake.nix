{
  description = "NixOS configuration for what is shareable publicly";

  inputs = {
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-stable.follows = "nixos-22_11";
    nixos-22_11.url = "github:NixOS/nixpkgs/nixos-22.11";

    nixpkgs.follows = "nixos-stable";

    nixcfg = {
      url = "github:msteen/nixcfg.lib";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    extra-container = {
      url = "github:erikarvstedt/extra-container";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-22.11";
      inputs.nixpkgs.follows = "nixos-stable";
      inputs.utils.follows = "extra-container/flake-utils";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixos-unstable";
      inputs.nixpkgs-stable.follows = "nixos-stable";
    };
  };

  outputs = inputs:
    inputs.nixcfg.lib.mkNixcfg {
      name = "public";
      path = ./.;
      inherit inputs;
    };
}
