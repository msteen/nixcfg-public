{ lib, config, pkgs, ... }:

let
  inherit (builtins) attrNames isAttrs listToAttrs;

  recursiveUpdateNames = f: attrs: listToAttrs (map (name: {
    name = f name;
    value = let
      value = attrs.${name};
    in
      if isAttrs value
      then recursiveUpdateNames f value
      else value;
  }) (attrNames attrs));

in let
  inherit (builtins) replaceStrings toFile toJSON;
  inherit (lib) mkDoc mkEnableOption mkIf mkOption;

  cfg = config.services.xtdb;

  configurationFile = toFile "configuration.json" (toJSON (recursiveUpdateNames (name: replaceStrings ["_"] ["/"] name) cfg.configuration));

  # TODO: Environment

in {
  options.services.xtdb = let inherit (lib.types) attrs package path; in {
    enable = mkEnableOption "XTDB";

    workDir = mkOption {
      type = path;
      default = "/var/lib/xtdb";
      description = ''
        The state directory of XTDB.
      '';
    };

    package = mkOption {
      type = package;
      default = pkgs.xtdb;
      description = ''
        The package containing XTDB.
      '';
    };

    configuration = mkOption {
      type = attrs;
      default = { };
      description = ''
        The [modules configuration](https://docs.xtdb.com/administration/configuring/) that will passed to XTDB as a JSON file.
        To make it easier to define them in Nix, we replace `_` to `/` in the attribute set names.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.xtdb = {
      description = "XTDB";
      script = ''
        ${pkgs.jre}/bin/java -jar ${pkgs.xtdb}/xtdb.jar -f ${configurationFile}
      '';
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}