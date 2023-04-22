{
  lib,
  config,
  nixcfg,
  ...
}: let
  inherit (builtins)
    listToAttrs
    ;
  inherit (lib)
    const
    genAttrs
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optional
    ;
  inherit (nixcfg.lib)
    concatAttrs
    ;

  types = {
    real = "that are \"real\" (i.e. a person)";
    normal = "marked as normal";
    home = "that exist in /home or that are normal";
  };

  cfg = config.users;
in {
  options.users = let
    inherit (lib.types)
      int
      listOf
      str
      submodule
      ;
  in
    {
      admin = mkOption {
        type = str;
        description = ''
          The primary admin of the host.
        '';
      };

      admins = mkOption {
        type = listOf str;
        default = [ ];
        description = ''
          List of admin user names.
        '';
      };
    }
    // concatAttrs (mapAttrsToList (type: description: {
        "${type}Users" = mkOption {
          type = listOf (submodule ({ name, ... }: {
            options = {
              id = mkOption {
                type = int;
                description = ''
                  The user and group id of this ${type} user.
                '';
              };

              name = mkOption {
                type = str;
                default = name;
                description = ''
                  The user and group name of this ${type} user.
                '';
              };
            };
          }));
          default = [ ];
          description = ''
            List of users ${description}.
          '';
        };

        "${type}Names" = mkOption {
          type = listOf str;
          readOnly = true;
          default = map ({ name, ... }: name) cfg."${type}Users";
          description = ''
            List of user names ${description}.
          '';
        };
      })
      types);

  config = mkMerge [
    (mkIf (cfg.admins != [ ]) {
      users.users = genAttrs cfg.admins (const { extraGroups = [ "wheel" ]; });
      nix.settings.trusted-users = cfg.admins;
    })
    {
      users.groups = listToAttrs (map ({
        id,
        name,
        ...
      }:
        nameValuePair name {
          gid = id;
          inherit name;
        })
      cfg.realUsers);

      users.users = listToAttrs (map ({
        id,
        name,
        ...
      }:
        nameValuePair name {
          isNormalUser = true;
          uid = id;
          inherit name;
          group = name;
          extraGroups =
            [
              "audio"
              "sshusers"
              "users"
              "video"
            ]
            ++ optional config.networking.networkmanager.enable "networkmanager";
          initialPassword = "test"; # FIXME!
          home = "/home/${name}";
          useDefaultShell = true;
        })
      cfg.realUsers);
    }
  ];
}
