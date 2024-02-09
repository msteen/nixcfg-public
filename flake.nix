{
  description = "NixOS configuration for what is shareable publicly";

  inputs = {
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-stable.follows = "nixos-23_11";
    nixos-23_11.url = "github:NixOS/nixpkgs/nixos-23.11";

    nixpkgs.follows = "nixos-stable";

    nixcfg = {
      url = "github:msteen/nixcfg.lib";
      inputs.nixpkgs.follows = "nixos-stable";
    };

    extra-container = {
      url = "github:erikarvstedt/extra-container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixos-23_11";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixos-unstable";
      inputs.nixpkgs-stable.follows = "nixos-stable";
    };

    nixos-vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixos-stable";
      inputs.flake-utils.follows = "extra-container/flake-utils";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.nixcfg.lib.mkNixcfgFlake {
      name = "public";
      inherit inputs;
    };
}
