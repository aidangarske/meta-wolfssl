# Configuration variable to enable/disable replace-default mode
# Inherit wolfprovider-replace-default in your image recipe to enable replace-default mode
# Default is "0" - replace-default is opt-in

WOLFPROVIDER_REPLACE_DEFAULT ??= "0"

python __anonymous() {
    mode = d.getVar('WOLFPROVIDER_REPLACE_DEFAULT')
    if mode == '1':
        bb.note("OpenSSL: wolfProvider REPLACE-DEFAULT mode ENABLED")
    else:
        bb.note("OpenSSL: normal mode (replace-default disabled)")
}

# OpenSSL target-only tweaks
do_configure:prepend:class-target () {
    if [ "${WOLFPROVIDER_REPLACE_DEFAULT}" = "1" ]; then
        set -eu

        # Be explicit about where we are
        echo "TARGET do_configure prepend: S='${S}', B='${B}'"

        vfile="${S}/VERSION.dat"

        # Sanity check: VERSION.dat must exist at the top of the OpenSSL tree
        if [ ! -f $vfile ]; then
            echo "ERROR: $vfile not found in ${S}" >&2
            exit 1
        fi

        echo "Injecting BUILD_METADATA into VERSION.dat (target only)"
        sed -i 's/^BUILD_METADATA=.*/BUILD_METADATA=wolfProvider/' $vfile

        # Optional FIPS tag based on image features
        if echo "${IMAGE_FEATURES}" | grep -qw "fips"; then
            sed -i 's/^BUILD_METADATA=.*/BUILD_METADATA=wolfProvider-fips/' $vfile
        fi
    fi
}

# Ensure provider is present on TARGET runtime (doesn't touch -native/-nativesdk)
RDEPENDS:libcrypto3:append:class-target = " wolfprovider"

# Build OpenSSL as plain, non-FIPS OpenSSL (only when replace-default enabled)
# wolfProvider will provide FIPS functionality using wolfSSL FIPS
# Override gekkOS setting which enables OpenSSL FIPS
PACKAGECONFIG:class-target:pn-openssl = "${@'' if d.getVar('WOLFPROVIDER_REPLACE_DEFAULT') == '1' else ''}"
EXTRA_OECONF:append:class-target = "${@' no-fips' if d.getVar('WOLFPROVIDER_REPLACE_DEFAULT') == '1' else ''}"

# Bring in/Apply your replace-default patch (target only)
SRC_URI:append:class-target = " \
    ${@'git://github.com/wolfSSL/wolfProvider.git;protocol=https;nobranch=1;rev=v1.1.0;destsuffix=git/wolfProvider' if d.getVar('WOLFPROVIDER_REPLACE_DEFAULT') == '1' else ''} \
"

python do_patch:append:class-target () {
    if d.getVar("WOLFPROVIDER_REPLACE_DEFAULT") == "1":
        import os, subprocess
        s = d.getVar("S")
        patch_path = os.path.join(d.getVar("WORKDIR"), "git/wolfProvider/patches/openssl3-replace-default.patch")
        bb.note("REPLACE-DEFAULT MODE: Applying replace-default patch")
        bb.note(f"REPLACE-DEFAULT MODE: Patch path {patch_path}")
        subprocess.run(["patch", "-d", s, "-p1", "-i", patch_path], check=True)
    else:
        bb.note("NORMAL MODE: Skipping replace-default patch")
}

