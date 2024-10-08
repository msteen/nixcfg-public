{ lib, stdenv, fetchurl, fetchpatch, python3, pkgconfig, perl, libxslt, docbook_xsl
, docbook_xml_dtd_42, readline
, popt, iniparser, libbsd, libarchive, libiconv, gettext
, krb5Full, zlib, openldap, cups, pam, avahi, acl, libaio, fam, libceph, glusterfs
, gnutls, ncurses, libunwind, systemd, jansson, lmdb, gpgme, libuuid

, enableLDAP ? false
, enablePrinting ? false
, enableMDNS ? false
, enableDomainController ? true
, enableRegedit ? true
, enableCephFS ? false
, enableGlusterFS ? false
, enableAcl ? true
, enablePam ? true
}:

stdenv.mkDerivation rec {
  pname = "samba";
  version = "4.11.5";

  src = lib.fetchurl {
    url = "mirror://samba/pub/samba/stable/${pname}-${version}.tar.gz";
    sha256 = "0gyr773dl0krcra6pvyp8i9adj3r16ihrrm2b71c0974cbzrkqpk";
  };

  outputs = [ "out" "dev" "man" ];

  patches = [
    ./4.x-no-persistent-install.patch
    ./patch-source3__libads__kerberos_keytab.c.patch
    ./4.x-no-persistent-install-dynconfig.patch
    ./4.x-fix-makeflags-parsing.patch
    (lib.fetchpatch {
      name = "test-oLschema2ldif-fmemopen.patch";
      url = "https://gitlab.com/samba-team/samba/commit/5e517e57c9d4d35e1042a49d3592652b05f0c45b.patch";
      sha256 = "1bbldf794svsdvcbp649imghmj0jck7545d3k9xs953qkkgwkbxi";
    })
  ];

  buildInputs = [
    (python3.withPackages (pkgs: with pkgs; [ dnspython ]))
    pkgconfig perl libxslt docbook_xsl docbook_xml_dtd_42 readline popt iniparser jansson
    libbsd libarchive zlib fam libiconv gettext libunwind krb5Full gnutls
  ] ++ lib.optionals stdenv.isLinux [ libaio systemd ]
    ++ lib.optional enableLDAP openldap
    ++ lib.optional (enablePrinting && stdenv.isLinux) cups
    ++ lib.optional enableMDNS avahi
    ++ lib.optionals enableDomainController [ gpgme lmdb ]
    ++ lib.optional enableRegedit ncurses
    ++ lib.optional (enableCephFS && stdenv.isLinux) libceph
    ++ lib.optionals (enableGlusterFS && stdenv.isLinux) [ glusterfs libuuid ]
    ++ lib.optional enableAcl acl
    ++ lib.optional enablePam pam;

  postPatch = ''
    # Removes absolute paths in scripts
    sed -i 's,/sbin/,,g' ctdb/config/functions

    # Fix the XML Catalog Paths
    sed -i "s,\(XML_CATALOG_FILES=\"\),\1$XML_CATALOG_FILES ,g" buildtools/wafsamba/wafsamba.py

    patchShebangs ./buildtools/bin
  '';

  # This is set automatically at some point in 20.09pre.
  # PYTHON = "${python}/bin/python";

  configureFlags = [
    "--with-static-modules=NONE"
    "--with-shared-modules=ALL"
    "--enable-fhs"
    "--sysconfdir=/etc"
    "--with-configdir=/etc/samba-addc"
    "--localstatedir=/var"
    "--disable-rpath"
  ] ++ lib.optional (!enableDomainController) "--without-ad-dc"
    ++ lib.optionals (!enableLDAP) [ "--without-ldap" "--without-ads" ]
    ++ lib.optional (!enableAcl) "--without-acl-support"
    ++ lib.optional (!enablePam) "--without-pam";

  preBuild = ''
    export MAKEFLAGS="-j $NIX_BUILD_CORES"
  '';

  # Some libraries don't have /lib/samba in RPATH but need it.
  # Use find -type f -executable -exec echo {} \; -exec sh -c 'ldd {} | grep "not found"' \;
  # Looks like a bug in installer scripts.
  postFixup = ''
    export SAMBA_LIBS="$(find $out -type f -name \*.so -exec dirname {} \; | sort | uniq)"
    read -r -d "" SCRIPT << EOF || true
    [ -z "\$SAMBA_LIBS" ] && exit 1;
    BIN='{}';
    OLD_LIBS="\$(patchelf --print-rpath "\$BIN" 2>/dev/null | tr ':' '\n')";
    ALL_LIBS="\$(echo -e "\$SAMBA_LIBS\n\$OLD_LIBS" | sort | uniq | tr '\n' ':')";
    patchelf --set-rpath "\$ALL_LIBS" "\$BIN" 2>/dev/null || exit;
    patchelf --shrink-rpath "\$BIN";
    EOF
    find $out -type f -name \*.so -exec $SHELL -c "$SCRIPT" \;
  '';

  meta = with stdenv.lib; {
    homepage = "https://www.samba.org";
    description = "The standard Windows interoperability suite of programs for Linux and Unix";
    license = licenses.gpl3;
    platforms = platforms.unix;
    maintainers = with maintainers; [ aneeshusa ];
  };
}
