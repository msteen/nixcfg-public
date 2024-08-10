{ config, pkgs, ... }:

with import ../../lib;

let
  cfg = config.services.nginx;
  user = config.users.users.www-data.name;
  group = config.users.groups.www-data.name;

in {
  options = with types; {
    services.nginx = {
      openPorts = mkOption {
        type = bool;
        default = true;
        description = ''
          Open the default ports used by Nginx for HTTP (80) and HTTPS (443) in the firewall.
        '';
      };

      http = mkOption {
        type = attrsOf lines;
        default = {};
        description = ''
          The server config for HTTP domains.
        '';
      };

      https = mkOption {
        type = attrsOf lines;
        default = {};
        description = ''
          The server config for HTTPS domains.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.etc."nginx/fastcgi_params".source = "${pkgs.nginx}/conf/fastcgi_params";

      users.users.www-data = {
        inherit group;
        isSystemUser = true;
      };
      users.groups.www-data = { };

      services.nginx = {
        user = mkDefault "www-data";
        group = mkDefault "www-data";
        config = mkBefore ''
          include /run/nginx-nixcfg/shared/nginx.conf;
        '';
        httpConfig = mkBefore ''
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

      networking.firewall.allowedTCPPorts = mkIf cfg.openPorts [ 80 443 ];

      system.activationScripts.nginx-nixcfg = stringAfter [ "users" "groups" ] ''
        mkdir -p /run/nginx-nixcfg
        ln -sfT ${config.path ../config/nginx} /run/nginx-nixcfg/shared
      '';
    }
    {
      users.users.dehydrated = { name = cfg.user; group = cfg.group; };
      users.groups.dehydrated = { name = cfg.group; };

      services.dehydrated.domains = genAttrs (attrNames cfg.https) (const []);

      services.nginx.httpConfig = concatStrings (
        mapAttrsToList (domain: serverConfig: optionalString (serverConfig != "" || (cfg.https.${domain} or "") != "") ''
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
        mapAttrsToList (domain: serverConfig: optionalString (serverConfig != "") ''
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
