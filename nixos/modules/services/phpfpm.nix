{ config, lib, ... }:

{
  options = with types; {
    services.phpfpm = {
      user = lib.mkOption {
        type = str;
        default = config.users.users.www-data.name;
        description = ''
          User account under which PHP-FPM runs.
        '';
      };

      group = lib.mkOption {
        type = str;
        default = config.users.groups.www-data.name;
        description = ''
          Group account under which PHP-FPM runs.
        '';
      };
    };
  };
}
