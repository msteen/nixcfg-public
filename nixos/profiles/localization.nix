{ lib, ... }: let
  inherit (lib) mkDefault mkForce;
in {
  # Localization
  time.timeZone = "Europe/Amsterdam";

  console.keyMap = mkDefault "us";

  i18n = {
    # Without forcing duplicates could occur, which breaks the checking done in the locale generation.
    supportedLocales = mkForce [
      "en_US.UTF-8/UTF-8"
      "en_US/ISO-8859-1"
      "nl_NL.UTF-8/UTF-8"
      "nl_NL/ISO-8859-1"
      "nl_NL@euro/ISO-8859-15"
    ];

    defaultLocale = "en_US.UTF-8";
  };
}
