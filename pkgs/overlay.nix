final: prev:
with final; {
  shellScriptAttrs = attrs: builtins.mapAttrs (name: writeShellScript "${name}.sh");

  xtdb = xtdbInMemory;
  xtdbInMemory = callPackage ./xtdb { };
  xtdbStandaloneRocksDB = callPackage ./xtdb { standaloneRocksDB = true; };
}
