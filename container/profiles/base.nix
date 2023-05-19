{
  lib,
  profiles,
  ...
} @ args: {
  imports = lib.attrValues {
    inherit (profiles.public) foo;
  };
}
