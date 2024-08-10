{ config, lib, ... }:

with lib;

{
  config = mkIf (config.boot.loader.grub.enable && config.boot.initrd.secrets != {}) {
    boot.loader = {
      supportsInitrdSecrets = mkForce true;
      grub.extraInitrd = "/boot/grub/secrets-initrd.gz";
      grub.extraPrepareConfig = ''
        ${config.system.build.initialRamdiskSecretAppender}/bin/append-initrd-secrets /boot/grub/secrets-initrd.gz
      '';
    };
  };
}
