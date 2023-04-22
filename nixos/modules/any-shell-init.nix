{
  lib,
  config,
  ...
}: let
  inherit (lib) mkBefore mkOption;

  cfg = config.environment;

  guardedAnyShellInit = ''
    if [ -z "$__NIXOS_ANY_SHELL_INIT_DONE" ]; then
      ${cfg.anyShellInit}
    fi
  '';

  shellEnv = ''
    if [ -z "$__NIXOS_SET_ENVIRONMENT_DONE" ]; then
      . ${config.system.build.setEnvironment}
    fi
    ${guardedAnyShellInit}
  '';
in {
  options.environment.anyShellInit = let
    inherit (lib.types) lines;
  in
    mkOption {
      type = lines;
      description = ''
        Shell script code called during any shell initialization.
      '';
    };

  config.environment = {
    anyShellInit = ''
      __NIXOS_ANY_SHELL_INIT_DONE=1
    '';
    loginShellInit = guardedAnyShellInit;
    interactiveShellInit = guardedAnyShellInit;

    variables.BASH_ENV = "/etc/bashenv";
    etc.bashenv.text = mkBefore shellEnv;
    etc.zshenv.text = mkBefore shellEnv;
  };
}
