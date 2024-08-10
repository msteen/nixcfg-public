{ stdenv, python }:

stdenv.mkDerivation rec {
  pname = "lnover";
  version = "0.1.0";
  description = "Link together files (last wins) and directories (overlay when needed)";

  buildInputs = [ python ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    substitute ${./main.py} $out/bin/${pname} \
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
