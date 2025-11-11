# OpenSSL target-only tweaks
do_configure:prepend:class-target () {
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
}

# Ensure provider is present on TARGET runtime (doesn't touch -native/-nativesdk)
RDEPENDS:libcrypto3:append:class-target = " wolfprovider"

# Build OpenSSL as plain, non-FIPS OpenSSL
# wolfProvider will provide FIPS functionality using wolfSSL FIPS
# Override gekkOS setting which enables OpenSSL FIPS
# Keep provider module support (needed for wolfProvider), but disable FIPS provider
PACKAGECONFIG:class-target = ""
EXTRA_OECONF:append:class-target = " no-fips"

# Bring in/Apply your replace-default patch (target only)
SRC_URI:append:class-target = " \
    git://github.com/wolfSSL/wolfProvider.git;protocol=https;nobranch=1;rev=v1.1.0;destsuffix=git/wolfProvider \
"

python do_patch:append:class-target () {
    import os, subprocess
    s = d.getVar("S")
    patch_path = os.path.join(d.getVar("WORKDIR"), "git/wolfProvider/patches/openssl3-replace-default.patch")
    bb.note(f"Applying wolfProvider patch (target only): {patch_path}")
    subprocess.run(["patch", "-d", s, "-p1", "-i", patch_path], check=True)
}
