# OpenSSL wolfProvider REPLACE-DEFAULT mode configuration
# This file is included when wolfProvider is configured to replace OpenSSL's default crypto provider
# It should be included from the image recipe when replace-default mode is desired

# Build OpenSSL as plain, non-FIPS OpenSSL
# wolfProvider will provide FIPS functionality using wolfSSL FIPS
# Note: The patch removes non-FIPS algorithms from both default and legacy providers
EXTRA_OECONF:append:class-target = " no-fips shared "

# OpenSSL target-only tweaks for replace-default mode
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

# Override do_configure to filter enable-fips from the actual configure command
do_configure:append:class-target () {
    # The base do_configure uses ${PACKAGECONFIG_CONFARGS} which still has enable-fips
    # We need to regenerate it without enable-fips
    # Re-run configure with enable-fips explicitly removed
    if [ -f "${B}/configdata.pm" ] && grep -q "enable-fips" "${B}/configdata.pm" 2>/dev/null; then
        bbwarn "REPLACE-DEFAULT MODE: FIPS detected in config, forcing reconfigure without FIPS"
        cd "${B}"
        # Get the target from the original config
        target=$(grep "our \$config{target}" "${B}/configdata.pm" 2>/dev/null | sed "s/.*'\(.*\)'.*/\1/" || echo "linux-x86_64")
        # Reconfigure without enable-fips (patch will remove non-FIPS algorithms from providers)
        HASHBANGPERL="/usr/bin/env perl" PERL=perl PERL5LIB="${S}/external/perl/Text-Template-1.46/lib/" \
        perl "${S}/Configure" no-fips shared ${EXTRA_OECONF} ${DEPRECATED_CRYPTO_FLAGS} \
            --prefix=${prefix} --openssldir=${libdir}/ssl-3 --libdir=${libdir} "$target"
        perl "${B}/configdata.pm" --dump
    fi
}

# Ensure provider is present on TARGET runtime (doesn't touch -native/-nativesdk)
RDEPENDS:libcrypto3:append:class-target = " wolfprovider"

# Bring in the replace-default patch and non-FIPS algorithm removal patch (target only)
# The algorithm removal patch is in the same directory as this inc file
# Use WOLFSSL_LAYERDIR to ensure we reference the meta-wolfssl layer directory
# Use apply=no to prevent quilt from auto-applying; we'll apply it manually
FILESEXTRAPATHS:prepend:class-target = "${WOLFSSL_LAYERDIR}/inc/wolfprovider/openssl/files:"
SRC_URI:append:class-target = " \
    git://github.com/wolfSSL/wolfProvider.git;protocol=https;nobranch=1;rev=v1.1.0;destsuffix=git/wolfProvider \
    file://ossl-wp-algos-3.0.17.patch;apply=no \
"

python do_patch:append:class-target () {
    import os, subprocess
    s = d.getVar("S")
    workdir = d.getVar("WORKDIR")
    
    # Apply openssl3-replace-default.patch
    patch_path = os.path.join(workdir, "git/wolfProvider/patches/openssl3-replace-default.patch")
    if os.path.exists(patch_path):
        result = subprocess.run(["patch", "-d", s, "-p1", "-i", patch_path, "--dry-run"], 
                              capture_output=True, text=True, check=False)
        if result.returncode == 0:
            subprocess.run(["patch", "-d", s, "-p1", "-i", patch_path], check=True)
    
    # Apply algorithm removal patch
    algos_patch_path = os.path.join(workdir, "ossl-wp-algos-3.0.17.patch")
    if not os.path.exists(algos_patch_path):
        wolfssl_layerdir = d.getVar("WOLFSSL_LAYERDIR")
        algos_patch_path = os.path.join(wolfssl_layerdir, "inc/wolfprovider/openssl/files/ossl-wp-algos-3.0.17.patch")
    
    if os.path.exists(algos_patch_path):
        result = subprocess.run(["patch", "-d", s, "-p1", "-i", algos_patch_path, "--dry-run"], 
                              capture_output=True, text=True, check=False)
        if result.returncode == 0:
            subprocess.run(["patch", "-d", s, "-p1", "-i", algos_patch_path], check=True)
}


