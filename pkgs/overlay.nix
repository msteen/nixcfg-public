final: prev: {
  shellScriptAttrs = attrs: builtins.mapAttrs (name: writeShellScript "${name}.sh");

  confirm.bash = final.callPackage ./confirm.bash { };
  boot-deps = config:
    final.callPackage ../pkgs/boot-deps {
      inherit config;
      pkgs = self;
    };
  lnover = final.callPackage ./lnover { };
  mklinuxpba = final.callPackage ./mklinuxpba { };
  port-up = final.callPackage ./port-up { };
  samba-addc = final.callPackage ./samba-addc { };
  sedutil = final.callPackage ./sedutil { };
  sedutil-scripts = final.callPackage ./sedutil-scripts { };
  sedutil-scripts-unwrapped = final.callPackage ./sedutil-scripts/unwrapped.nix { };
  sysrq-scripts = final.callPackage ./sysrq-scripts { };
  wrapScript = final.makeSetupHook { deps = [ final.makeWrapper ]; } ./setup-hooks/wrap-script.sh;

  xtdb = xtdbInMemory;
  xtdbInMemory = callPackage ./xtdb { };
  xtdbStandaloneRocksDB = callPackage ./xtdb { standaloneRocksDB = true; };
}
