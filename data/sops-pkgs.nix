{ pkgs }: let
  inherit (builtins)
    attrValues
    ;
in
  attrValues { inherit (pkgs) sops ssh-to-age ssh-to-pgp; }
