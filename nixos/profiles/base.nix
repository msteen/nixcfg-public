{
  lib,
  pkgs,
  data,
  profiles,
  ...
}: {
  imports =
    lib.attrValues {
      inherit (profiles.public) localization;
    }
    ++ [ lib.dummyNixosModule ];

  environment.systemPackages =
    data.public.standard-pkgs { inherit pkgs; }
    ++ lib.attrValues {
      inherit (pkgs) nix-tree;
    };

  environment.shellAliases = {
    # If the last character of the alias value is a space or tab character,
    # then the next command word following the alias is also checked for alias expansion.
    sudo = "sudo ";

    grep = "grep --color=auto";
    la = "ls --all --human-readable -l";
    nano = "nano --nowrap";
    nix-build = "nix-build --no-out-link";
    nix-env = "nix-env --file '${toString pkgs.path}'";
    nix-eval = "nix-instantiate --eval --expr";
    nix-gc = "sudo nix-collect-garbage --delete-old";
    xargs = "xargs --no-run-if-empty";
  };
}
