{ lib, config, ... }:

let
  inherit (builtins) attrValeus;
  inherit (lib) mkDefault;

in {
  services.xserver = {
    enable = true;
    exportConfiguration = true;
    layout = mkDefault "us";
    xkbVariant = mkDefault "euro";
    xkbOptions = mkDefault "compose:menu";
    displayManager = {
      lightdm.enable = true;
      autoLogin = {
        enable = true;
        autoLogin.user = mkDefault config.users.admin;
      };
    };
  };

  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    fonts = attrValues {
      inherit (pkgs)
        dejavu_fonts
        iosevka
        ubuntu_font_family
        ;
    };
  };
}
