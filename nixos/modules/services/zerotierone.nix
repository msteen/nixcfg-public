{ config, lib, ... }:

{
  config = lib.mkIf config.services.zerotierone.enable {
    environment.sudoAliases = lib.map (name: "zerotier-${name}") [ "cli" "idtool" "one" ];
  };
}
