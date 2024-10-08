{ config, pkgs, ... }:

let
  inherit (lib) types;
  cfg = config.services.nginx;
  user = config.users.users.www-data.name;
  group = config.users.groups.www-data.name;

in {
  options = {
    services.nginx = {
      openPorts = lib.mkOption {
        type = typesbool;
        default = true;
        description = ''
          Open the default ports used by Nginx for HTTP (80) and HTTPS (443) in the firewall.
        '';
      };

      http = lib.mkOption {
        type = types.attrsOf types.lines;
        default = {};
        description = ''
          The server config for HTTP domains.
        '';
      };

      https = lib.mkOption {
        type = types.attrsOf types.lines;
        default = {};
        description = ''
          The server config for HTTPS domains.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.etc."nginx/fastcgi_params".source = "${pkgs.nginx}/conf/fastcgi_params";

      users.users.www-data = {
        inherit group;
        isSystemUser = true;
      };
      users.groups.www-data = { };

      services.nginx = {
        user = lib.mkDefault "www-data";
        group = lib.mkDefault "www-data";
        config = lib.mkBefore ''
          include /run/nginx-nixcfg/shared/nginx.conf;
        '';
        httpConfig = lib.mkBefore ''
          include /run/nginx-nixcfg/shared/http.conf;
        '';
      };

      security.pam.loginLimits = [
        # Matches `worker_connections` of nginx.conf
        { domain = user; type = "soft"; item = "nproc";  value  = "4096"; }
        { domain = user; type = "hard"; item = "nproc";  value  = "4096"; }

        # Matches `worker_rlimit_nofile` of nginx.conf
        { domain = user; type = "soft"; item = "nofile"; value  = "65536"; }
        { domain = user; type = "hard"; item = "nofile"; value  = "65536"; }
      ];

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openPorts [ 80 443 ];

      system.activationScripts.nginx-nixcfg = lib.stringAfter [ "users" "groups" ] ''
        mkdir -p /run/nginx-nixcfg
        ln -sfT ${config.path ../config/nginx} /run/nginx-nixcfg/shared
      '';
    }
    {
      users.users.dehydrated = { name = cfg.user; group = cfg.group; };
      users.groups.dehydrated = { name = cfg.group; };

      services.dehydrated.domains = lib.genAttrs (lib.attrNames cfg.https) (lib.const []);

      services.nginx.httpConfig = lib.concatStrings (
        lib.mapAttrsToList (domain: serverConfig: lib.optionalString (serverConfig != "" || (cfg.https.${domain} or "") != "") ''
          server {
            deny 54.87.234.78;
            deny 5.188.62.26;
            deny 5.188.62.76;
            deny 5.188.62.21;
            deny 5.188.62.140;
            listen 80;
            server_name ${domain};
            include /run/nginx-nixcfg/shared/drop.conf;
            ${optionalString ((cfg.https.${domain} or "") != "") ''
              # Redirect HTTP to HTTPS.
              location / {
                return 301 https://$host$request_uri;
              }
            '' + serverConfig}
          }
        '') cfg.http ++
        lib.mapAttrsToList (domain: serverConfig: lib.optionalString (serverConfig != "") ''
          server {
            deny 54.87.234.78;
            deny 5.188.62.26;
            deny 5.188.62.76;
            deny 5.188.62.21;
            deny 5.188.62.140;
            include /run/nginx-nixcfg/shared/ssl.conf;
            ssl_certificate /var/lib/dehydrated/certs/${domain}/fullchain.pem;
            ssl_certificate_key /var/lib/dehydrated/certs/${domain}/privkey.pem;
            server_name ${domain};
            include /run/nginx-nixcfg/shared/drop.conf;
            ${serverConfig}
          }
        '') cfg.https
      );
    }
  ]);
}
