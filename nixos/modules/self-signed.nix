{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (builtins)
    attrValues
    concatStringsSep
    replaceStrings
    ;
  inherit (lib)
    mapAttrs'
    mkOption
    nameValuePair
    optionalString
    ;
  inherit (lib.types)
    attrsOf
    listOf
    str
    submodule
    ;

  cfg = config.self-signed;

  root = "/var/lib/self-signed";

  selfSignedModule = {
    name,
    config,
    ...
  }: {
    options = {
      domain = mkOption {
        type = str;
        default = name;
        example = "example.com";
        description = ''
          The domain for which a self-signed certificate needs to be generated.
        '';
      };
      extraDomainNames = mkOption {
        type = listOf str;
        default = [ ];
        example = [ "example.org" ];
        description = ''
          A list of extra domain names to be added to the self-signed certificate being generated.
        '';
      };
      owner = mkOption {
        type = str;
        default = "root";
        example = "acme";
        description = ''
          The user that will own the self-signed certificate.
        '';
      };
      group = mkOption {
        type = str;
        default = "root";
        example = "acme";
        description = ''
          The group that will own the self-signed certificate.
        '';
      };
      key = mkOption {
        type = str;
        readOnly = true;
        default = "${root}/${name}/key.pem";
        description = ''
          The absolute path to the self-signed certificate key file.
        '';
      };
      cert = mkOption {
        type = str;
        readOnly = true;
        default = "${root}/${name}/cert.pem";
        description = ''
          The absolute path to the self-signed certificate cert file.
        '';
      };
    };
  };
in {
  options.self-signed = mkOption {
    type = attrsOf (submodule selfSignedModule);
    default = { };
    description = ''
      Generate self-signed certificates.
    '';
  };

  config = {
    systemd.services =
      mapAttrs' (
        name: cfg:
          nameValuePair "self-signed-${name}"
          {
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = cfg.owner;
              Group = cfg.group;
              StateDirectory = "self-signed/${name}";
              StateDirectoryMode = 755;
              WorkingDirectory = dirOf cfg.cert;
            };
            unitConfig = {
              ConditionPathExists = "!${cfg.cert}";
            };
            path = attrValues { inherit (pkgs) openssl; };
            script = let
              ext = "subjectAltName=${concatStringsSep "," (map (domain: "DNS:${domain}") cfg.extraDomainNames)}";
              addext = optionalString (cfg.extraDomainNames != [ ]) " \\\n  -addext \"${ext}\"";
            in ''
              openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
                -keyout key.pem -out cert.pem -subj "/CN=${cfg.domain}"${addext}

              chown '${cfg.owner}:${cfg.group}' {key,cert}.pem

              # Due to potential use in ACME tools, it needs to be group readable.
              chmod 640 key.pem
              chmod 644 cert.pem
            '';
            before = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
          }
      )
      cfg;
  };
}
