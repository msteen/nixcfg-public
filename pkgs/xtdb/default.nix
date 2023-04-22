{
  lib,
  stdenv,
  fetchurl,
  standaloneRocksDB ? false,
}:
stdenv.mkDerivation rec {
  pname = "xtdb";
  version = "1.23.1";

  src =
    if standaloneRocksDB
    then
      fetchurl {
        url = "https://github.com/xtdb/xtdb/releases/download/${version}/xtdb-standalone-rocksdb.jar";
        sha256 = "sha256-+L3kOLk2P3WEk/wTM3VkNrFFASE9o6hAclEFPL/wszQ=";
      }
    else
      fetchurl {
        url = "https://github.com/xtdb/xtdb/releases/download/${version}/xtdb-in-memory.jar";
        sha256 = "ha256-bWUrXWIGkN0WCOV4HtAx37vFLUx4K/2Ueu7XGZkhGAM=";
      };

  buildCommand = "
    mkdir -p $out
    mv $src $out/xtdb.jar
  ";

  meta = let
    inherit (builtins) attrValues;
    inherit (lib) licenses maintainers platforms sourceTypes;
  in {
    description = "General-purpose bitemporal database for SQL, Datalog & graph queries";
    homepage = https://xtdb.com/;
    license = licenses.mit;
    platforms = platforms.all;
    sourceProvenance = attrValues {
      inherit (sourceTypes)
        binaryBytecode
        binaryNativeCode
        ;
    };
    maintainers = attrValues {
      inherit (maintainers)
        msteen
        ;
    };
  };
}
