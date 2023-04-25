{
  lib,
  pkgs,
  inputs,
  ...
}: f: let
  inherit (builtins)
    attrValues
    ;
  inherit (lib)
    mkIf
    mkMerge
    ;
in {
  config = mkIf (inputs ? sops-nix) (mkMerge [
    (f (attrValues { inherit (pkgs) sops ssh-to-age ssh-to-pgp; }))
    {
      sops = {
        # FIXME: We probably want a systemd service that automatically generates the age key file based on our ssh key.
        # age.sshKeyPaths = map (x: x.path) (filter (x: x.type == "ed25519") config.services.openssh.hostKeys);
        # age.keyFile = "/var/lib/sops-nix/key.txt";
      };
    }
  ]);
}
