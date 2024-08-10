{ config, lib, ... }:

let
  inherit (lib) types;
  cfg = config.environment;

in {
  options.environment.sudoAliases = lib.mkOption {
    default = [];
    type = types.listOf types.str;
    description = ''
      A list of executables that should always be prepended with sudo.
    '';
  };

  config = lib.mkIf (cfg.sudoAliases != []) {
    environment.shellAliases = lib.genAttrs cfg.sudoAliases (alias: "sudo ${alias}");
  };
}
