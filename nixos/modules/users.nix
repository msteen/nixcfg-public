{ lib, config, ... }:

let
  inherit (builtins) listToAttrs;
  inherit (lib) const genAttrs mkIf mkMerge mkOption nameValuePair optional;

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
      type = listOf str;
      default = [];
      description = ''
        List of admin user names.
      '';
    };

    realNames = mkOption {
      type = listOf str;
      default = map ({ name, ... }: name) cfg.realUsers;
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

  config = mkMerge [
    (mkIf (cfg.admins != []) {
      users.users = genAttrs cfg.admins (const { extraGroups = [ "wheel" ]; });
      nix.settings.trusted-users = cfg.admins;
    })
    {
      users.groups = listToAttrs (map ({ id, name, ... }: nameValuePair name {
        gid = id;
        inherit name;
      }) cfg.realUsers);

      users.users = listToAttrs (map ({ id, name, ... }: nameValuePair name {
        isNormalUser = true;
        uid = id;
        inherit name;
        group = name;
        extraGroups = [
          "audio"
          "sshusers"
          "users"
          "video"
        ] ++ optional config.networking.networkmanager.enable "networkmanager";
        initialPassword = "test"; # FIXME!
        home = "/home/${name}";
        useDefaultShell = true;
      }) cfg.realUsers);
    }
  ];
}
