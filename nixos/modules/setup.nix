{ lib, config, pkgs, flake, hostname, ... }:

let
  inherit (lib) concatMapStrings imap1 mkAfter mkDefault mkEnableOption mkIf mkMerge mkOption mkOrder optional optionalString types;
  inherit (flake.lib) lines' nonl setFailFast;

  cfg = config.setup;
  label = if cfg.enableWindowsSupport && cfg.firmware == "bios" then "mbr" else "gpt";
  isBiosGpt = cfg.firmware == "bios" && label == "gpt";

  gptPartitionTypes = {
    "BIOS boot partition"   = "21686148-6449-6E6F-744E-656564454649";
    "EFI system partition"  = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";
    "swap partition"        = "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F";
    "Linux filesystem data" = "0FC63DAF-8483-4772-8E79-3D69D8477DE4";
    "LUKS partition"        = "CA7D7CCB-63ED-4C53-861C-1742536059CC";
  };

  mbrPartitionTypes = {
    "swap partition"        = "82";
    "Linux filesystem data" = "83";
    "LUKS partition"        = "E8";
  };

  devOffset = if isBiosGpt then 1 else 0;
  dev = n: cfg.device + optionalString cfg.enableNvme "p" + toString (devOffset + n);

  setDevVars = nonl (if cfg.enableEncryption then ''
    boot_dev=${dev 1}
    swap_dev=/dev/${cfg.poolName}/swap
    root_dev=/dev/${cfg.poolName}/root
  '' else ''
    boot_dev=${dev 1}
    swap_dev=${dev 2}
    root_dev=${dev 3}
  '');

  mountDevs = ''
    echo "Mount the file systems..." >&2

    mkdir -p /mnt
    mount -t zfs ${cfg.poolName}/system/nixos /mnt

    mkdir -p /mnt/boot
    mount "$boot_dev" /mnt/boot

    # TODO: Detect if it is safe to do so.
    # swapon "$swap_dev"

    mkdir -p /mnt/{home,nix}
    mount -t zfs ${cfg.poolName}/user/home /mnt/home
    mount -t zfs ${cfg.poolName}/cache/nix /mnt/nix
  '';

in {
  options.setup = let inherit (types) enum int lines nullOr str; in {
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

    poolName = mkOption {
      type = str;
      default = "zroot";
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
        boot.loader = if cfg.firmware == "uefi" then {
          efi.canTouchEfiVariables = true;
          grub = {
            efiSupport = true;
            device = "nodev";
          };
        } else {
          grub = { inherit (cfg) device; };
        };
      })
      {
        boot.initrd.luks.devices.root = mkIf cfg.enableEncryption {
          device = dev 2;
          allowDiscards = true;
          preLVM = true;
        };

        boot.supportedFilesystems = [ "zfs" ];

        setup.script = mkMerge [
          (let
            biosPartition = {
              size = "1MiB";
              type = "BIOS boot partition";
            };

            bootPartition = {
              size = "${toString cfg.bootSize}MiB";
              type = if cfg.firmware == "uefi" then "EFI system partition" else "Linux filesystem data";
            };

            sfdisk = partitions: nonl ''
              echo "Partition device '${cfg.device}'..." >&2
              sfdisk ${cfg.device} <<'EOF'
              unit: sectors
              label: ${label}
              ${lines' (imap1 (order: { size ? null, type }: nonl ''
                ${toString order} :${optionalString (size != null) " size=${size}"} type=${
                  (if label == "gpt" then gptPartitionTypes else mbrPartitionTypes).${type}}
              '') (optional isBiosGpt biosPartition ++ [ bootPartition ] ++ partitions))}
              EOF
              sleep 1
            '';

          in mkOrder 0 ''
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

            ${nonl (if cfg.enableEncryption then ''
              ${sfdisk [
                { type = "LUKS partition"; }
              ]}

              echo "LUKS encrypt the LVM partition..." >&2
              echo -n "$passwd" | cryptsetup luksFormat --type luks2 --key-file=- --batch-mode ${dev 2}
              echo -n "$passwd" | cryptsetup open --type luks2 --key-file=- ${dev 2} root

              echo "Initalize LVM within the encrypted partition..." >&2
              pvcreate /dev/mapper/root
              vgcreate ${cfg.poolName} /dev/mapper/root
              lvcreate --size ${toString cfg.swapSize} --name swap ${cfg.poolName}
              lvcreate --extents 100%FREE --name root ${cfg.poolName}
            '' else sfdisk [
                { size = "${toString cfg.swapSize}MiB"; type = "swap partition"; }
                { type = "Linux filesystem data"; }
            ])}

            ${setDevVars}

            ${nonl (if cfg.firmware == "uefi" then ''
              echo "Format the boot partition as FAT32..." >&2
              mkfs.vfat -F 32 "$boot_dev" -n boot
            '' else ''
              echo "Format the boot partition as ext2..." >&2
              mkfs.ext2 -F "$boot_dev" -L boot
            '')}

            echo "Format the swap partition..." >&2
            mkswap -f "$swap_dev" -L swap

            echo "Format the root partition as ZFS..." >&2
            zpool create -f \
              -O atime=on -O relatime=on \
              -O xattr=sa \
              -O acltype=posixacl \
              -O compression=lz4 \
              -O normalization=formD \
              -o ashift=12 \
              -o altroot=/mnt \
              ${cfg.poolName} "$root_dev"

            # For files that can be reproduced, but are stored for performance.
            zfs create -o mountpoint=none ${cfg.poolName}/cache
            zfs create -o mountpoint=legacy -o atime=off -o relatime=off ${cfg.poolName}/cache/nix

            zfs create -o mountpoint=none ${cfg.poolName}/system
            zfs create -o mountpoint=legacy ${cfg.poolName}/system/nixos

            zfs create -o mountpoint=none ${cfg.poolName}/user
            zfs create -o mountpoint=legacy ${cfg.poolName}/user/home

            ${mountDevs}

            echo "Creating home directories..." >&2
            for user in root wheel ${toString config.users.realNames}; do
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
              mkdir -p /mnt/home/${user}/.ssh
              chmod -R 700 /mnt/home/${user}
              echo 'Include config.d/*' > /mnt/home/${user}/.ssh/config
              chmod 600 /mnt/home/${user}/.ssh/config
              ssh-keygen -t ed25519 -o -a 128 -C '${user}@${hostname}' -f /mnt/home/${user}/.ssh/id_ed25519 -N '''
            '') ([ "root" "wheel" ] ++ config.users.realNames)}

            echo "Fix ownership of directories..." >&2
            ${concatMapStrings ({ id, name, ... }: ''
              chown -R ${toString id}:${toString id} /mnt/home/${name}
            '') ([ { id = 1; name = "wheel"; } ] ++ config.users.realUsers)}

            echo "Generate NixOS hardware configuration..." >&2
            nixos-generate-config --root /mnt
            # FIXME: Target doesn't exist yet!
            # mv /mnt/etc/nixos/hardware-configuration.nix /mnt/cfg/${config.users.admin}/nixos/hosts/${hostname}/config/hardware-generated.nix
            ln -sfT /cfg/${config.users.admin}/flake.nix /mnt/etc/nixos/flake.nix

            echo "Printing public SSH key of admin..." >&2
            cat /mnt/home/${config.users.admin}/.ssh/id_ed25519.pub
          '')
        ];

        setup.mountScript = mountDevs;

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
