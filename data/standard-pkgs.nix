{ pkgs }: let
  inherit (builtins)
    attrValues
    ;
in
  attrValues { inherit (pkgs) micro wl-clipboard xclip; }
