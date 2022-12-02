{ lib, ... }:

let
  inherit (lib) mkOption types;

in {
  options.users = let inherit (types) int listOf str submodule; in {
    admin = mkOption {
      type = str;
    };

    admins = mkOption {
      type = listOf str;
    };

    realNames = mkOption {
      type = listOf str;
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
}
