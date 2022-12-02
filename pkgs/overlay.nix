final: prev: with final; {
  shellScriptAttrs = attrs: builtins.mapAttrs (name: pkgs.writeShellScript "${name}.sh");
}
