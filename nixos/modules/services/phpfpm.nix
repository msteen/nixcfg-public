{ config, lib, ... }: let
  inherit (lib) types;
in
{
  options = {
    services.phpfpm = {
      user = lib.mkOption {
        type = types.str;
        default = config.users.users.www-data.name;
        description = ''
          User account under which PHP-FPM runs.
        '';
      };

      group = lib.mkOption {
        type = types.str;
        default = config.users.groups.www-data.name;
        description = ''
          Group account under which PHP-FPM runs.
        '';
      };
    };
  };
}
