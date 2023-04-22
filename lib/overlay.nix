final: prev:
with final; {
  applyIf = b: f: x:
    if b
    then f x
    else x;
  notNullOr = default: value:
    if value != null
    then value
    else default;

  setFailFast = "set -euo pipefail";

  ensureRoot = ''
    if [ $(id -u) -ne 0 ]; then
      if command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
      else
        echo "This script should be run as root." >&2
        exit 1
      fi
    fi
  '';

  ensureNotRoot = ''
    if [ $(id -u) -eq 0 ]; then
      echo "This script should not be run as root." >&2
      exit 1
    fi
  '';

  unlines = lines: builtins.splitString "\n" (builtins.removeSuffix "\n" lines);
  lines = lines: builtins.concatMapStrings (line: line + "\n") lines;
  lines' = lines: builtins.concatStringsSep "\n" lines;
  nonl = text: lib.removeSuffix "\n" text;
}
