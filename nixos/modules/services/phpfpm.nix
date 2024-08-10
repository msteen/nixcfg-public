{ config, lib, ... }:

with lib;

{
  options = with types; {
    services.phpfpm = {
      user = mkOption {
        type = str;
        default = config.users.users.www-data.name;
        description = ''
          User account under which PHP-FPM runs.
        '';
      };

      group = mkOption {
        type = str;
        default = config.users.groups.www-data.name;
        description = ''
          Group account under which PHP-FPM runs.
        '';
      };
    };
  };
}