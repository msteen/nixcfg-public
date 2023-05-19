{ config }: {
  virtualisation.lxd.enable = true;

  users.users.${config.users.admin} = {
    extraGroups = [ "lxd" ];
  };
}
