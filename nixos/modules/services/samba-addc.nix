{ config, lib, pkgs, ... }:

let
  inherit (lib) types;
  cfg = config.services.samba-addc;

  sambaToString = x: if builtins.typeOf x == "bool" then if x then "yes" else "no" else lib.toString x;

  shareConfig = name: let share = lib.getAttr name cfg.shares; in ''
    [${name}]
    ${concatStrings (map (key: ''
      ${"  "}${key} = ${sambaToString share.${key}}
    '') (attrNames share))}
  '';

  configFile = if cfg.configFile != null then cfg.configFile else pkgs.writeText "smb.conf" ''
    [global]
      nsupdate command = ${pkgs.dnsutils}/bin/nsupdate -g
      passwd program = /run/wrappers/bin/passwd %u
      template shell = ${pkgs.coreutils}/bin/false

    ${cfg.extraConfig}
    ${concatStringsSep "\n" (map shareConfig (attrNames cfg.shares))}
  '';

in {
  options.services.samba-addc = {
    enable = lib.mkEnableOption "Samba server";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.samba-addc;
      defaultText = "pkgs.samba-addc";
      description = ''
        Defines which package should be used for the samba server.
      '';
    };

    configFile = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        The Samba server config file <literal>smb.conf</literal>.
        If null (default), it will be generated based on <literal>extraConfig</literal>
        and <literal>shares</literal>.
      '';
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = ''
        Additional global section and extra section lines go in here.
      '';
      example = ''
        guest account = nobody
        map to guest = bad user
      '';
    };

    shares = lib.mkOption {
      type = types.attrsOf (types.attrsOf types.unspecified);
      default = {};
      description = ''
        A set describing shared resources. See <command>man smb.conf</command> for options.
      '';
      example = {
        public = {
          "path" = "/srv/public";
          "read only" = true;
          "browseable" = "yes";
          "guest ok" = "yes";
          "comment" = "Public samba share.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."samba-addc/smb.conf".source = configFile;

    environment.systemPackages = [ cfg.package ];

    systemd.services.samba = {
      description = "Samba Active Directory Domain Controller";
      after = [ "network.target" ];
      environment.LOCALE_ARCHIVE = "/run/current-system/sw/lib/locale/locale-archive";
      unitConfig.RequiresMountsFor = "/var/lib/samba";
      serviceConfig = {
        Type = "forking";
        ExecStart = "${cfg.package}/bin/samba -D";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        PIDFile = "/run/samba/samba.pid";
      };
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configFile ];
    };

    systemd.tmpfiles.rules = [
      "d /var/cache/samba - - - - -"
      "d /var/lib/samba/private - - - - -"
      "d /var/lock/samba - - - - -"
      "d /var/log/samba - - - - -"
      "d /run/samba - - - - -"
    ];
  };
}
