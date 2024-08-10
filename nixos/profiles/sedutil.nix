{ config, lib, pkgs, ... }:

{
  boot.kernelParams = [ "libata.allow_tpm=1" ];

  # https://aur.archlinux.org/cgit/aur.git/tree/mkinitcpio.conf.lib?h=sedutil
  boot.initrd.kernelModules = [
    "algif_skcipher"
    "dm-crypt"
    "loop"
    "xts"
  ];

  environment.systemPackages = with pkgs; [
    mklinuxpba
    sedutil
    sedutil-scripts
  ];
}
