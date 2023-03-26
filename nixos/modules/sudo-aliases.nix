{ lib, config, ... }:

let
  inherit (lib) genAttrs mkIf mkOption;
  inherit (lib.types) listOf str;

  cfg = config.environment;

in {
  options.environment.sudoAliases = mkOption {
    default = [];
    type = listOf str;
    description = ''
      A list of executables that should always be called with sudo.
    '';
  };

  config = mkIf (cfg.sudoAliases != []) {
    environment.shellAliases = genAttrs cfg.sudoAliases (alias: "sudo ${alias}");
  };
}
