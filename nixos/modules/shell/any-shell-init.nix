{ config, lib, ... }:

let
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
  options.environment.anyShellInit = with types; lib.mkOption {
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
    etc.bashenv.text = lib.mkBefore shellEnv;
    etc.zshenv.text = lib.mkIf config.programs.zsh.enable (lib.mkBefore shellEnv);
  };
}
