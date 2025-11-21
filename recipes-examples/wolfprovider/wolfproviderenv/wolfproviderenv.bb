SUMMARY = "Test suite for wolfProvider OpenSSL provider"
DESCRIPTION = "Enviroment setup for wolfProvider OpenSSL provider"
HOMEPAGE = "https://www.wolfssl.com"
SECTION = "examples"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

DEPENDS = "openssl pkgconfig-native virtual/wolfssl wolfprovider"
PROVIDES += "wolfproviderenv"
RPROVIDES_${PN} = "wolfproviderenv"

SRC_URI = "file://wolfproviderenv.c \
           file://wolfproviderenv.sh \
           file://wolfprov-check-algs.sh \
          "

S = "${WORKDIR}"

inherit pkgconfig

do_compile() {
    ${CC} ${WORKDIR}/wolfproviderenv.c -o wolfproviderverify \
        ${CFLAGS} ${LDFLAGS} $(pkg-config --cflags --libs openssl) -ldl -lwolfssl -lwolfprov
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/wolfproviderverify ${D}${bindir}/wolfproviderverify
    install -m 0755 ${WORKDIR}/wolfproviderenv.sh ${D}${bindir}/wolfproviderenv
    install -m 0755 ${WORKDIR}/wolfprov-check-algs.sh ${D}${bindir}/wolfprov-check-algs
}

FILES_${PN} += "${bindir}/wolfproviderverify ${bindir}/wolfproviderenv ${bindir}/wolfprov-check-algs"

# Dynamic RDEPENDS adjustment for bash and optional coreutils and procps
python() {
    distro_version = d.getVar('DISTRO_VERSION', True)
    pn = d.getVar('PN', True)

    rdepends_var_name = 'RDEPENDS_' + pn if (distro_version.startswith('2.') or distro_version.startswith('3.')) else 'RDEPENDS:' + pn

    current_rdepends = d.getVar(rdepends_var_name, True) or ""
    new_rdepends = current_rdepends + " bash coreutils procps"
    d.setVar(rdepends_var_name, new_rdepends)
}
