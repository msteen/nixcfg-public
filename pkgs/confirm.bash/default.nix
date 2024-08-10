{ stdenv, bash }:

stdenv.mkDerivation rec {
  pname = "confirm.bash";
  version = "0.1.0";
  description = "Prompt for confirmation within the console using Bash";

  buildInputs = [ bash ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    substitute ${./confirm.bash} $out/bin/${pname} \
      --subst-var-by pname "$pname" \
      --subst-var-by version "$version" \
      --subst-var-by description "$description"
    chmod +x $out/bin/${pname}
  '';

  dontStrip = true;
  dontPatchELF = true;

  meta = with stdenv.lib; {
    inherit description;
    license = licenses.mit;
    maintainers = with maintainers; [ msteen ];
    platforms = platforms.all;
  };
}
