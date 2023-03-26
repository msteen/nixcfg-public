{ lib, ... }:

let
  inherit (lib) mkOption;

  cfg = config.users;

in {
  options.users = let inherit (lib.types) int listOf str submodule; in {
    admin = mkOption {
      type = str;
      description = ''
        The primary admin of the host.
      '';
    };

    admins = mkOption {
      default = [];
      type = listOf str;
      description = ''
        List of admin user names.
      '';
    };

    realNames = mkOption {
      type = listOf str;
      description = ''
        List of real user (i.e. person) names.
      '';
    };

    realUsers = mkOption {
      type = listOf (submodule {
        options = {
          id = mkOption {
            type = int;
            description = ''
              The user and group id of this real user (i.e. person), should be >= 1000.
            '';
          };

          name = mkOption {
            type = str;
            description = ''
              The user and group name of this real user (i.e. person).
            '';
          };
        };
      });
    };
  };

  config = mkIf (cfg.adminUsers != []) {
    users.users = genAttrs cfg.adminUsers (const { extraGroups = [ "wheel" ]; });
    nix.trustedUsers = cfg.adminUsers;
  };
}
