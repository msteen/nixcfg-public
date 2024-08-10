{ lib, stdenv, fetchurl, fetchpatch

, acl
, attr
, avahi
, cups
, dnsutils
, docbook_xml_dtd_42
, docbook_xsl
, gawk
, glusterfs
, gnused
, gnutar
, gnutls
, gpgme
, gzip
, hostname
, icu
, jansson
, keyutils
, libaio
, libarchive
, libbsd
, libcap
, libceph
, libiconv
, libnsl
, libpcap
, libtasn1
, libtirpc
, libunwind
, liburing
, libuuid
, libxslt
, linuxquota
, lmdb
, ncurses
, nettle
, openldap
, pam
, perl
, pkgconfig
, popt
, procps
, psmisc
, python3
, readline
, rng-tools
, rsync
, sudo
, systemd
, tree
, utillinux
, which
, xfsprogs
, zlib

, enableCephFS ? false
, enableGlusterFS ? false
, enableLDAP ? false
, enableMDNS ? false
, enablePrinting ? false
, enableRegedit ? true
}:

let
  python3Packages = pkgs: with pkgs; [
    dnspython
    gpgme
    markdown
    pycrypto
  ];

in stdenv.mkDerivation rec {
  pname = "samba";
  version = "4.11.7";

  src = lib.fetchurl {
    url = "mirror://samba/pub/samba/stable/${pname}-${version}.tar.gz";
    sha256 = "0hr1qjn249lfiazbrr0ya7sgkpn6dp9dbqjka643ydspqgmzkdkr";
  };

  outputs = [ "out" "dev" "man" ];

  patches = [
    ./4.x-fix-makeflags-parsing.patch
    ./4.x-no-persistent-install-dynconfig.patch
    ./4.x-no-persistent-install.patch
    ./patch-source3__libads__kerberos_keytab.c.patch
    (lib.fetchpatch {
      name = "test-oLschema2ldif-fmemopen.patch";
      url = "https://gitlab.com/samba-team/samba/commit/5e517e57c9d4d35e1042a49d3592652b05f0c45b.patch";
      sha256 = "1bbldf794svsdvcbp649imghmj0jck7545d3k9xs953qkkgwkbxi";
    })
  ];

  buildInputs = [
    (python3.withPackages python3Packages)
    acl
    attr
    dnsutils
    docbook_xml_dtd_42
    docbook_xsl
    gawk
    gnused
    gnutar
    gnutls
    gpgme
    gzip
    hostname
    icu
    jansson
    keyutils
    libaio
    libarchive
    libbsd
    libcap
    libiconv
    libnsl
    libpcap
    libtasn1
    libtirpc
    libunwind
    liburing
    libxslt
    linuxquota
    lmdb
    nettle
    pam
    perl
    pkgconfig
    popt
    procps
    psmisc
    python3
    readline
    rng-tools
    rsync
    sudo
    systemd
    tree
    utillinux
    which
    xfsprogs
    zlib
  ]
  ++ lib.optional enableCephFS libceph
  ++ lib.optionals enableGlusterFS [ glusterfs libuuid ]
  ++ lib.optional enableLDAP openldap
  ++ lib.optional enableMDNS avahi
  ++ lib.optional enablePrinting cups
  ++ lib.optional enableRegedit ncurses;

  postPatch = ''
    # Removes absolute paths in scripts.
    sed -i 's,/sbin/,,g' ctdb/config/functions

    # Fix the XML catalog files.
    sed -i "s,\(XML_CATALOG_FILES=\"\),\1$XML_CATALOG_FILES ,g" buildtools/wafsamba/wafsamba.py

    patchShebangs ./buildtools/bin
  '';

  configureFlags = [
    "--disable-rpath"
    "--enable-fhs"
    "--localstatedir=/var"
    "--sysconfdir=/etc"
    "--with-configdir=/etc/samba-addc"
    "--with-shared-modules=ALL"
    "--with-static-modules=NONE"
  ] ++ lib.optionals (!enableLDAP) [ "--without-ldap" "--without-ads" ];

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
    platforms = platforms.linux;
    maintainers = with maintainers; [ aneeshusa msteen ];
  };
}
