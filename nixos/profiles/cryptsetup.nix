{ pkgs, ... }:

{
  boot.initrd = {
    availableKernelModules = [
      "aes_generic"
      "aes_x86_64"
      "aes"
      "af_alg"
      "algif_skcipher"
      "blowfish"
      "cbc"
      "cryptd"
      "dm_crypt"
      "dm_mod"
      "ecb"
      "input_leds"
      "lrw"
      "serpent"
      "sha1"
      "sha256"
      "sha512"
      "twofish"
      "xts"
    ];

    extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
    '';
  };

  environment.systemPackages = lib.attrValues { inherit (pkgs) cryptsetup; };

  environment.sudoAliases = [ "cryptsetup" ];
}
