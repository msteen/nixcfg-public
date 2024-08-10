{ lib, writeBashBin, setFailFast, ensureRoot, exportNixosConfig
, coreutils, utillinux, bash, gptfdisk, syslinux, dosfstools, nix, gnutar, gzip, git }:

# https://wiki.archlinux.org/index.php/syslinux
# https://aur.archlinux.org/cgit/aur.git/tree/mklinuxpba-diskimg?h=sedutil
writeBashBin "mklinuxpba" ''
  ${setFailFast}
  ${ensureRoot}

  ${exportNixosConfig}

  export PATH=${makeBinPath [ coreutils utillinux gptfdisk syslinux dosfstools nix gnutar gzip git ]}

  export NIXOS_EXTRA_MODULE_PATH=$(nix-build --no-out-link --expr \
  'with import <nixpkgs> { }; pkgs.writeText "dummy-root-file-system.nix" '"'''"'{
    boot.initrd.linuxpba.enable = true;
  }'"'''")
  deps=$(nix-build --no-out-link --expr 'with import <nixpkgs/nixos> { }; pkgs.boot-deps' --show-trace)
  if (( $? > 0 )) || [[ -z $deps ]]; then
    echo "Failed to build the kernel or initial ramdisk." >&2
    exit 1
  fi

  img=$(mktemp --tmpdir=/tmp linuxpba-XXXXXXXXXX.img)
  mnt=$(mktemp --tmpdir=/tmp --directory linuxpba-XXXXXXXXXX)

  cp ${syslinux}/share/syslinux/gptmbr.bin "$img"
  truncate -s 32M "$img"
  sgdisk -n 1:0:0 -t 1:ef00 -A 1:set:2 "$img" > /dev/null

  loopdev="$(losetup --show -f "$img")"
  partx -a "$loopdev"

  mkfs.vfat -n SEDUTIL_PBA "''${loopdev}p1" > /dev/null
  syslinux --install "''${loopdev}p1"

  mount "''${loopdev}p1" "$mnt"

  cp $deps/{kernel,initrd} "$mnt"

  if [[ -f $deps/append-initrd-secrets ]]; then
    $deps/append-initrd-secrets "$mnt/initrd"
  fi

  # BIOS (the other files are installed via `syslinux --install`)
  echo "${''
    default linuxpba
    prompt 0
    noescape 1
    label linuxpba
      kernel /kernel
      initrd /initrd
      append ''$(< $deps/kernel-params)
  ''}" > "$mnt/syslinux.cfg"

  # EFI
  mkdir -p "$mnt/EFI/BOOT"
  cp ${./syslinux.efi} "$mnt/EFI/BOOT/bootx64.efi"
  cp ${./ldlinux.e64} "$mnt/EFI/BOOT/ldlinux.e64"
  cp "$mnt/syslinux.cfg" "$mnt/EFI/BOOT/syslinux.cfg"

  umount "$mnt"
  rmdir "$mnt"

  partx -d "$loopdev"
  losetup -d "$loopdev"

  chmod 644 "$img"
  echo "$img"
''
