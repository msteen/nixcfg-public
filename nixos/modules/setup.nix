{
  lib,
  config,
  pkgs,
  nixcfg,
  ...
}: let
  inherit (lib) concatMapStrings imap1 mkAfter mkDefault mkEnableOption mkIf mkMerge mkOption mkOrder optional optionalString singleton types;
  inherit (nixcfg.lib) lines' nonl setFailFast;

  cfg = config.setup;
  label =
    if cfg.enableWindowsSupport && cfg.firmware == "bios"
    then "mbr"
    else "gpt";
  isBiosGpt = cfg.firmware == "bios" && label == "gpt";

  gptPartitionTypes = {
    "BIOS boot partition" = "21686148-6449-6E6F-744E-656564454649";
    "EFI system partition" = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";
    "swap partition" = "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F";
    "Linux filesystem data" = "0FC63DAF-8483-4772-8E79-3D69D8477DE4";
    "LUKS partition" = "CA7D7CCB-63ED-4C53-861C-1742536059CC";
  };

  mbrPartitionTypes = {
    "swap partition" = "82";
    "Linux filesystem data" = "83";
    "LUKS partition" = "E8";
  };

  devOffset =
    if isBiosGpt
    then 1
    else 0;
  dev = n: cfg.device + optionalString cfg.enableNvme "p" + toString (devOffset + n);

  devices =
    if cfg.enableEncryption
    then {
      boot = dev 1;
      swap = "/dev/${cfg.volumeGroup}/swap";
      root = "/dev/${cfg.volumeGroup}/root";
    }
    else {
      boot = dev 1;
      swap = dev 2;
      root = dev 3;
    };

  setDevVars = nonl ''
    boot_dev=${devices.boot}
    swap_dev=${devices.swap}
    root_dev=${devices.root}
  '';

  btrfsOptions = "compress-force=zstd:22,noatime";

  mountDevs = ''
    echo "Mount the file systems..." >&2

    mkdir -p /mnt
    mount -t btrfs -o subvol=system/nixos,${btrfsOptions} "$root_dev" /mnt

    mkdir -p /mnt/boot
    mount "$boot_dev" /mnt/boot

    (( $(swapon --show=type --noheadings | wc -l) > 0 )) && swapon "$swap_dev"

    mkdir -p /mnt/{home,nix}
    mount -t btrfs -o subvol=user/home,${btrfsOptions} "$root_dev" /mnt/home
    mount -t btrfs -o subvol=cache/nix,${btrfsOptions} "$root_dev" /mnt/nix
  '';
in {
  options.setup = let
    inherit (types) enum int lines nullOr str;
  in {
    firmware = mkOption {
      type = nullOr (enum [ "bios" "uefi" ]);
      default = null;
    };

    device = mkOption {
      type = nullOr str;
      default = null;
    };

    enableNvme = mkEnableOption "NVMe support";

    enableEncryption = mkEnableOption "encryption";

    enableWindowsSupport = mkEnableOption "Windows dual boot support";

    bootSize = mkOption {
      type = int;
      default = 512;
    };

    swapSize = mkOption {
      type = int;
      default = 1024;
    };

    volumeGroup = mkOption {
      type = str;
      default = "lvm";
    };

    script = mkOption {
      type = lines;
    };

    mountScript = mkOption {
      type = lines;
    };
  };

  config = mkMerge [
    # {
    #   assertions = [ { assertion = cfg.device == null || cfg.firmware != null; message = ''
    #     You have defined setup.device but left setup.firmware undefined, this is likely a mistake.
    #   ''; } ];
    # }
    (mkIf (cfg.firmware != null) (mkMerge [
      (mkDefault {
        boot.loader =
          if cfg.firmware == "uefi"
          then {
            efi.canTouchEfiVariables = true;
            grub = {
              efiSupport = true;
              device = "nodev";
            };
          }
          else {
            grub = { inherit (cfg) device; };
          };
      })
      {
        boot.initrd.luks.devices.root = mkIf cfg.enableEncryption {
          device = dev 2;
          allowDiscards = true;
          preLVM = true;
        };

        boot.supportedFilesystems = [ "btrfs" ];

        setup.script = mkMerge [
          (let
            biosPartition = {
              size = "1MiB";
              type = "BIOS boot partition";
            };

            bootPartition = {
              size = "${toString cfg.bootSize}MiB";
              type =
                if cfg.firmware == "uefi"
                then "EFI system partition"
                else "Linux filesystem data";
            };

            sfdisk = partitions:
              nonl ''
                echo "Partition device '${cfg.device}'..." >&2
                sfdisk ${cfg.device} <<'EOF'
                unit: sectors
                label: ${label}
                ${lines' (imap1 (order: {
                  size ? null,
                  type,
                }:
                  nonl ''
                    ${toString order} :${optionalString (size != null) " size=${size}"} type=${
                      (
                        if label == "gpt"
                        then gptPartitionTypes
                        else mbrPartitionTypes
                      )
                      .${type}
                    }
                  '') (optional isBiosGpt biosPartition ++ [ bootPartition ] ++ partitions))}
                EOF
                sleep 1
              '';
          in
            mkOrder 0 ''
              ${setFailFast}

              dev=$(realpath '${cfg.device}')
              if ! [[ $dev =~ ^/dev/[a-z]+$ ]]; then
                echo "Could not resolve device '${cfg.device}' to a /dev/ path." >&2
                exit 1
              fi

              ${optionalString cfg.enableEncryption (nonl ''
                while :; do
                  read -s -p "Encryption password: " passwd
                  echo
                  read -s -p "Encryption password (verify): " passwd_verify
                  echo
                  if [[ -z $passwd ]]; then
                    echo "Encryption password cannot be empty, try again." >&2
                    continue
                  fi
                  [[ $passwd == $passwd_verify ]] && break || echo "Encryption passwords did not match, try again." >&2
                done
              '')}

              ${nonl (
                if cfg.enableEncryption
                then ''
                  ${sfdisk [
                    { type = "LUKS partition"; }
                  ]}

                  echo "LUKS encrypt the LVM partition..." >&2
                  echo -n "$passwd" | cryptsetup luksFormat --type luks2 --key-file=- --batch-mode ${dev 2}
                  echo -n "$passwd" | cryptsetup open --type luks2 --key-file=- ${dev 2} root

                  echo "Initalize LVM within the encrypted partition..." >&2
                  pvcreate /dev/mapper/root
                  vgcreate ${cfg.volumeGroup} /dev/mapper/root
                  lvcreate --size ${toString cfg.swapSize} --name swap ${cfg.volumeGroup}
                  lvcreate --extents 100%FREE --name root ${cfg.volumeGroup}
                ''
                else
                  sfdisk [
                    {
                      size = "${toString cfg.swapSize}MiB";
                      type = "swap partition";
                    }
                    { type = "Linux filesystem data"; }
                  ]
              )}

              ${setDevVars}

              ${nonl (
                if cfg.firmware == "uefi"
                then ''
                  echo "Format the boot partition as FAT32..." >&2
                  mkfs.vfat -F 32 "$boot_dev" -n boot
                ''
                else ''
                  echo "Format the boot partition as ext2..." >&2
                  mkfs.ext2 -F "$boot_dev" -L boot
                ''
              )}

              echo "Format the swap partition..." >&2
              mkswap -f "$swap_dev" -L swap

              (
                echo "Format the root partition as btrfs..." >&2
                mkfs.btrfs -L root "$root_dev"

                mkdir -p /mnt
                mount -t btrfs -o ${btrfsOptions} "$root_dev" /mnt
                cd /mnt

                # For files that can be reproduced, but are stored for performance.
                btrfs subvolume create cache
                btrfs subvolume create cache/nix
                btrfs subvolume create cache/nix/store

                btrfs subvolume create system
                btrfs subvolume create system/nixos

                btrfs subvolume create user
                btrfs subvolume create user/home

                umount /mnt
              )

              ${mountDevs}

              echo "Creating home directories..." >&2
              for user in root wheel ${toString config.users.normalNames}; do
                mkdir /mnt/home/$user
              done

              echo "Link paths..." >&2
              ln -s /home/root /mnt/root
              ln -s /home/wheel /mnt/wheel
              ln -s /home/${config.users.admin} /mnt/admin
            '')
          (mkAfter ''
            echo "Create SSH config for users..." >&2
            ${concatMapStrings (user: ''
              mkdir -p /mnt/home/${user}/.ssh/config.d
              chmod -R 700 /mnt/home/${user}
              echo 'Include config.d/*' > /mnt/home/${user}/.ssh/config
              chmod 600 /mnt/home/${user}/.ssh/config
              ssh-keygen -t ed25519 -o -a 128 -C '${user}@${config.networking.hostName}' -f /mnt/home/${user}/.ssh/id_ed25519 -N '''
            '') ([ "root" "wheel" ] ++ config.users.normalNames)}

            echo "Fix ownership of directories..." >&2
            ${concatMapStrings ({
                id,
                name,
                ...
              }: ''
                chown -R ${toString id}:${toString id} /mnt/home/${name}
              '')
              config.users.normalUsers}

            echo "Generate NixOS hardware configuration..." >&2
            nixos-generate-config --root /mnt

            echo "Printing public SSH key of admin..." >&2
            cat /mnt/home/${config.users.admin}/.ssh/id_ed25519.pub
          '')
        ];

        setup.mountScript = ''
          ${setFailFast}
          ${setDevVars}
          ${mountDevs}
        '';

        system.build.setup-nixos-install = pkgs.writeShellScript "setup-nixos-install.sh" cfg.script;
        system.build.mount-nixos-install = pkgs.writeShellScript "mount-nixos-install.sh" cfg.mountScript;

        # system.build = pkgs.shellScriptAttrs {
        #   setup-nixos-install = cfg.script;
        #   mount-nixos-install = cfg.mountScript;
        # };
      }
    ]))
  ];
}
