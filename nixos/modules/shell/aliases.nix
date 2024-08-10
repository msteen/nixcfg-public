{ config, lib, ... }:

let
  cfg = config.environment;

in {
  options.environment.sudoAliases = with types; lib.mkOption {
    default = [];
    type = lib.listOf str;
    description = ''
      A list of executables that should always be prepended with sudo.
    '';
  };

  config = lib.mkIf (cfg.sudoAliases != []) {
    environment.shellAliases = lib.genAttrs cfg.sudoAliases (alias: "sudo ${alias}");
  };
}
