# wolfssl-commercial.bbclass
#
# This class provides helper functions for commercial wolfSSL bundles
# including password-protected 7z extraction and autogen disabling
#
# Usage in recipe:
#   inherit wolfssl-commercial
#
# Required variables:
#   COMMERCIAL_BUNDLE_DIR - Directory containing the commercial archive
#   COMMERCIAL_BUNDLE_NAME - Logical bundle name (used as extracted directory)
#   COMMERCIAL_BUNDLE_PASS - Password for .7z bundles (optional for .tar.gz)
#   COMMERCIAL_BUNDLE_SHA - SHA256 checksum of the bundle
#   COMMERCIAL_BUNDLE_TARGET - Target directory for extraction (usually WORKDIR)
#
# Example:
#   COMMERCIAL_BUNDLE_DIR = "${@os.path.dirname(d.getVar('FILE'))}/commercial/files"
#   COMMERCIAL_BUNDLE_NAME = "${WOLFSSL_SRC}"
#   COMMERCIAL_BUNDLE_PASS = "${WOLFSSL_SRC_PASS}"
#   COMMERCIAL_BUNDLE_SHA = "${WOLFSSL_SRC_SHA}"
#   COMMERCIAL_BUNDLE_TARGET = "${WORKDIR}"
#
# Helper functions:
#   get_commercial_src_uri(d) - Generates conditional SRC_URI
#   get_commercial_source_dir(d) - Generates conditional source directory
#   get_commercial_bbclassextend(d) - Returns BBCLASSEXTEND only if bundle configured
#   get_commercial_bundle_archive(d) - Resolves bundle filename (supports .7z and .tar.gz)
#
# Optional format variables:
#   COMMERCIAL_BUNDLE_FILE - Bundle filename including extension (defaults to <NAME>.7z)
#   COMMERCIAL_BUNDLE_GCS_URI - gs:// path to the protected bundle
#   COMMERCIAL_BUNDLE_SRC_DIR - Direct path to already-extracted source directory (skips fetch/extract)

# Commercial bundles already ship generated configure scripts, so skip autoreconf
AUTOTOOLS_AUTORECONF = "no"

# Helper functions for conditional commercial bundle configuration
def append_libtool_sysroot(d):
    """Override the default autotools helper to drop --with-libtool-sysroot for commercial bundles."""
    if d.getVar('COMMERCIAL_BUNDLE_ENABLED') == "1":
        return ''
    import bb
    if not bb.data.inherits_class('native', d):
        return '--with-libtool-sysroot=${STAGING_DIR_HOST}'
    return ''

def get_commercial_bundle_archive(d):
    """Resolve the bundle filename with extension."""
    bundle_file = d.getVar('COMMERCIAL_BUNDLE_FILE')
    if bundle_file and bundle_file.strip() and not bundle_file.startswith('${'):
        return bundle_file
    bundle_name = d.getVar('COMMERCIAL_BUNDLE_NAME')
    if bundle_name and bundle_name.strip() and not bundle_name.startswith('${'):
        return f'{bundle_name}.7z'
    return ''

def get_commercial_src_uri(d):
    """Generate SRC_URI for commercial bundle if configured, dummy file otherwise"""
    # Check for direct source directory first (skip fetch/extract)
    src_dir = d.getVar('COMMERCIAL_BUNDLE_SRC_DIR')
    if src_dir and src_dir.strip() and not src_dir.startswith('${'):
        # Direct source directory - no fetch needed
        return ""

    bundle_archive = d.getVar('COMMERCIAL_BUNDLE_ARCHIVE')
    bundle_sha = d.getVar('COMMERCIAL_BUNDLE_SHA')
    gcs_uri = d.getVar('COMMERCIAL_BUNDLE_GCS_URI')
    placeholder = d.getVar('COMMERCIAL_BUNDLE_PLACEHOLDER') or ''

    if gcs_uri and bundle_archive:
        unpack_flag = ';unpack=false' if bundle_archive.endswith('.7z') else ''
        sha_flag = f';sha256sum={bundle_sha}' if bundle_sha else ''
        filename_flag = f';downloadfilename={bundle_archive}'
        return f'{gcs_uri}{filename_flag}{unpack_flag}{sha_flag}'

    bundle_dir = d.getVar('COMMERCIAL_BUNDLE_DIR')

    if bundle_archive and not gcs_uri:
        unpack_flag = ';unpack=false' if bundle_archive.endswith('.7z') else ''
        return f'file://{bundle_dir}/{bundle_archive}{unpack_flag};sha256sum={bundle_sha}'

    # Return dummy placeholder file when not configured
    if placeholder:
        return f'file://{placeholder}'
    return ""

def get_commercial_source_dir(d):
    """Get source directory for commercial bundle if configured, WORKDIR otherwise"""
    workdir = d.getVar('WORKDIR')
    bundle_name = d.getVar('COMMERCIAL_BUNDLE_NAME')

    # Check for direct source directory - return the copy location in WORKDIR
    src_dir = d.getVar('COMMERCIAL_BUNDLE_SRC_DIR')
    if src_dir and src_dir.strip() and not src_dir.startswith('${'):
        # do_commercial_extract will copy to WORKDIR/bundle_name
        if bundle_name and bundle_name.strip() and not bundle_name.startswith('${'):
            return f'{workdir}/{bundle_name}'
        # Fallback to workdir if bundle_name not set
        return workdir

    # Check if bundle_name is actually set (not empty, None, or unexpanded variable)
    if bundle_name and bundle_name.strip() and not bundle_name.startswith('${'):
        return f'{workdir}/{bundle_name}'
    return workdir

def get_commercial_bbclassextend(d):
    """Return BBCLASSEXTEND variants only when commercial bundle is configured"""
    bundle_name = d.getVar('COMMERCIAL_BUNDLE_NAME')

    # Check if bundle_name is actually set (not empty, None, or unexpanded variable)
    if bundle_name and bundle_name.strip() and not bundle_name.startswith('${'):
        return 'native nativesdk'
    return ''

# Generic variables for commercial bundle extraction
COMMERCIAL_BUNDLE_ENABLED ?= "0"
COMMERCIAL_BUNDLE_DIR ?= ""
COMMERCIAL_BUNDLE_NAME ?= ""
COMMERCIAL_BUNDLE_FILE ?= ""
COMMERCIAL_BUNDLE_PASS ?= ""
COMMERCIAL_BUNDLE_SHA ?= ""
COMMERCIAL_BUNDLE_TARGET ?= "${WORKDIR}"
COMMERCIAL_BUNDLE_PLACEHOLDER ?= "${WOLFSSL_LAYERDIR}/recipes-wolfssl/wolfssl/commercial/files/README.md"
COMMERCIAL_BUNDLE_GCS_URI ?= ""
COMMERCIAL_BUNDLE_SRC_DIR ?= ""
COMMERCIAL_BUNDLE_ARCHIVE = "${@get_commercial_bundle_archive(d)}"

# Task to extract commercial bundle
python do_commercial_extract() {
    import os
    import bb
    import bb.process
    import bb.build

    enabled = d.getVar('COMMERCIAL_BUNDLE_ENABLED')
    src_dir = d.getVar('COMMERCIAL_BUNDLE_SRC_DIR')
    bundle_dir = d.getVar('COMMERCIAL_BUNDLE_DIR')
    bundle_archive = d.getVar('COMMERCIAL_BUNDLE_ARCHIVE')
    bundle_pass = d.getVar('COMMERCIAL_BUNDLE_PASS')
    target_dir = d.getVar('COMMERCIAL_BUNDLE_TARGET')
    bundle_sha = d.getVar('COMMERCIAL_BUNDLE_SHA') or ''

    if enabled != "1":
        bb.note("COMMERCIAL_BUNDLE_ENABLED=0; skipping commercial extraction (standard fetch/unpack will run).")
        return

    # If direct source directory is provided, skip extraction
    if src_dir and src_dir.strip() and not src_dir.startswith('${'):
        bb.note(f"COMMERCIAL_BUNDLE_SRC_DIR={src_dir}; copying source directory to WORKDIR.")
        
        # Verify source directory exists and is not empty
        if not os.path.exists(src_dir):
            bb.fatal(f"COMMERCIAL_BUNDLE_SRC_DIR={src_dir} does not exist. Check WOLFSSL_SRC_DIRECTORY setting.")
        
        if not os.path.isdir(src_dir):
            bb.fatal(f"COMMERCIAL_BUNDLE_SRC_DIR={src_dir} is not a directory. Check WOLFSSL_SRC_DIRECTORY setting.")
        
        # Check if source directory has files
        items = os.listdir(src_dir)
        if not items:
            bb.fatal(f"COMMERCIAL_BUNDLE_SRC_DIR={src_dir} is empty. Check WOLFSSL_SRC_DIRECTORY setting.")
        
        bb.note(f"Source directory {src_dir} contains {len(items)} items")
        # Check for configure files in source directory
        has_configure = os.path.exists(os.path.join(src_dir, 'configure')) or \
                        os.path.exists(os.path.join(src_dir, 'configure.ac')) or \
                        os.path.exists(os.path.join(src_dir, 'configure.in'))
        if not has_configure:
            bb.warn(f"Source directory {src_dir} does not contain configure/configure.ac/configure.in")
            bb.warn(f"Contents: {', '.join(items[:10])}")
            if len(items) > 10:
                bb.warn(f"... and {len(items) - 10} more items")
        
        # Copy source directory to WORKDIR to avoid polluting the original
        import shutil
        bundle_name = d.getVar('COMMERCIAL_BUNDLE_NAME')
        dest_dir = os.path.join(target_dir, bundle_name)
        
        if os.path.exists(dest_dir):
            bb.note(f"Removing existing build directory: {dest_dir}")
            shutil.rmtree(dest_dir)
        
        bb.note(f"Copying {src_dir} to {dest_dir}")
        shutil.copytree(src_dir, dest_dir, symlinks=True)
        bb.note("Source directory copied successfully")
        return

    if not bundle_dir:
        bb.fatal("COMMERCIAL_BUNDLE_DIR not set. Please set the directory containing the commercial bundle.")

    if not bundle_archive:
        bb.fatal("COMMERCIAL_BUNDLE_NAME/FILE not set. Please provide the bundle filename.")

    is_seven_zip = bundle_archive.endswith('.7z')
    is_tarball = bundle_archive.endswith('.tar.gz') or bundle_archive.endswith('.tgz')

    if is_seven_zip and not bundle_pass:
        bb.fatal("COMMERCIAL_BUNDLE_PASS not set. Please set bundle password for .7z archives.")

    if not is_seven_zip:
        bb.note("Non-7z commercial bundle detected; letting BitBake unpack the archive.")
        return

    bundle_path = os.path.join(bundle_dir, bundle_archive)

    if not os.path.exists(bundle_path):
        bb.fatal(f"Commercial bundle not found: {bundle_path}\n" +
                 "Please download the commercial bundle and place it in the appropriate directory.\n" +
                 "Contact support@wolfssl.com for access to commercial bundles.")

    # Verify checksum locally (BitBake's file:// fetcher may skip it)
    if bundle_sha:
        import hashlib
        h = hashlib.sha256()
        with open(bundle_path, 'rb') as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b''):
                h.update(chunk)
        digest = h.hexdigest()
        if digest != bundle_sha:
            bb.fatal(f"SHA256 mismatch for {bundle_archive}:\n"
                     f"  expected: {bundle_sha}\n"
                     f"  actual:   {digest}\n"
                     "Update WOLFSSL_SRC_SHA/COMMERCIAL_BUNDLE_SHA to the correct value.")

    # Copy bundle to target directory
    bb.plain(f"Extracting commercial bundle: {bundle_archive}")
    ret = os.system(f'cp -f "{bundle_path}" "{target_dir}"')
    if ret != 0:
        bb.fatal(f"Failed to copy bundle to {target_dir}")

    archive_in_target = os.path.join(target_dir, bundle_archive)

    if is_seven_zip:
        # Locate 7zip binary from native sysroot or host
        path = d.getVar('PATH')
        seven_zip = bb.utils.which(path, '7za') or bb.utils.which(path, '7z')

        if not seven_zip:
            bb.fatal("Failed to find either '7za' or '7z' in PATH.\n"
                     "Ensure p7zip-native is available or install p7zip on the build host.")

        cmd = [seven_zip, 'x', archive_in_target, f"-p{bundle_pass}",
               f"-o{target_dir}", '-aoa']
    else:
        bb.fatal(f"Unsupported commercial bundle format: {bundle_archive}. Expected .7z.")

    try:
        bb.process.run(cmd)
    except bb.process.ExecutionError as exc:
        bb.fatal("Failed to extract bundle. Check credentials and bundle integrity.\n" + str(exc))

    # Verify extraction and list what was created
    bb.plain("Commercial bundle extracted successfully")
    bb.note(f"Contents of {target_dir} after extraction:")
    actual_source_dir = None
    for item in os.listdir(target_dir):
        item_path = os.path.join(target_dir, item)
        if os.path.isdir(item_path):
            bb.note(f"  Directory: {item}")
            # Check if this directory looks like the source
            if os.path.exists(os.path.join(item_path, 'configure')) or \
               os.path.exists(os.path.join(item_path, 'configure.ac')) or \
               os.path.exists(os.path.join(item_path, 'configure.in')):
                bb.note(f"    -> Contains configure files (likely source directory)")
                if not actual_source_dir:
                    actual_source_dir = item_path
            else:
                # Check subdirectories for configure files
                try:
                    for subitem in os.listdir(item_path):
                        subitem_path = os.path.join(item_path, subitem)
                        if os.path.isdir(subitem_path):
                            if os.path.exists(os.path.join(subitem_path, 'configure')) or \
                               os.path.exists(os.path.join(subitem_path, 'configure.ac')) or \
                               os.path.exists(os.path.join(subitem_path, 'configure.in')):
                                bb.note(f"    -> Subdirectory {subitem} contains configure files")
                                if not actual_source_dir:
                                    actual_source_dir = subitem_path
                except OSError:
                    pass
        elif os.path.isfile(item_path) and not item.endswith('.7z'):
            bb.note(f"  File: {item}")
    
    # Check if expected source directory exists and has files
    bundle_name = d.getVar('COMMERCIAL_BUNDLE_NAME')
    expected_dir = os.path.join(target_dir, bundle_name) if bundle_name and bundle_name.strip() and not bundle_name.startswith('${') else None
    
    if expected_dir:
        if os.path.exists(expected_dir) and os.path.isdir(expected_dir):
            items = os.listdir(expected_dir)
            if items:
                bb.note(f"Expected source directory '{expected_dir}' exists and contains {len(items)} items")
                # Verify it has configure files
                if not (os.path.exists(os.path.join(expected_dir, 'configure')) or \
                        os.path.exists(os.path.join(expected_dir, 'configure.ac')) or \
                        os.path.exists(os.path.join(expected_dir, 'configure.in'))):
                    bb.warn(f"Expected source directory '{expected_dir}' exists but doesn't contain configure files!")
                    if actual_source_dir and actual_source_dir != expected_dir:
                        bb.warn(f"Found source in '{actual_source_dir}' instead. Bundle structure may differ from WOLFSSL_SRC setting.")
                        bb.warn(f"You may need to adjust WOLFSSL_SRC='{bundle_name}' to match the extracted directory name.")
            else:
                bb.warn(f"Expected source directory '{expected_dir}' exists but is EMPTY!")
                if actual_source_dir:
                    bb.warn(f"Found source in '{actual_source_dir}' instead. The bundle extracted to a different directory name than WOLFSSL_SRC='{bundle_name}'")
                    bb.warn(f"Consider setting WOLFSSL_SRC to match the extracted directory, or use WOLFSSL_SRC_DIRECTORY to point directly to the source.")
                else:
                    bb.warn(f"Extraction may have failed - no source directory found with configure files!")
        else:
            if actual_source_dir:
                bb.warn(f"Expected source directory '{expected_dir}' does not exist, but found source in '{actual_source_dir}'")
                bb.warn(f"Bundle structure differs from WOLFSSL_SRC='{bundle_name}' setting.")
                bb.warn(f"Consider adjusting WOLFSSL_SRC to match the extracted directory name, or use WOLFSSL_SRC_DIRECTORY to point directly to the source.")
            else:
                bb.warn(f"Expected source directory '{expected_dir}' does not exist and no source directory found!")
}

# Add task after fetch, before patch (place before do_patch so it still runs even if do_unpack is skipped)
addtask commercial_extract after do_fetch before do_patch

# Conditionally add p7zip-native dependency only when commercial bundle variables are set
python __anonymous() {
    enabled = d.getVar('COMMERCIAL_BUNDLE_ENABLED')
    src_dir = d.getVar('COMMERCIAL_BUNDLE_SRC_DIR')
    archive = d.getVar('COMMERCIAL_BUNDLE_ARCHIVE')

    # Skip p7zip and unpack tasks if using direct source directory
    # But keep commercial_extract to copy the source
    if enabled == "1" and src_dir and src_dir.strip() and not src_dir.startswith('${'):
        bb.build.deltask('do_fetch', d)
        bb.build.deltask('do_unpack', d)
        # do_commercial_extract will copy the source directory
        return

    if enabled == "1" and archive and archive.endswith('.7z'):
        d.appendVar('DEPENDS', ' p7zip-native')
        d.appendVarFlag('do_commercial_extract', 'depends', ' p7zip-native:do_populate_sysroot')
        # Older BitBake releases sometimes ignore 'unpack=false' on file:// URLs,
        # causing do_unpack to run with no password and wipe the extracted tree.
        # When we manage a passworded .7z ourselves, skip do_unpack entirely.
        bb.build.deltask('do_unpack', d)

    # Commercial bundles ship preconfigured scripts; drop libtool sysroot flag
    opts = d.getVar('CONFIGUREOPTS') or ''
    import shlex
    tokens = shlex.split(opts)
    tokens = [t for t in tokens if not t.startswith('--with-libtool-sysroot=')]
    d.setVar('CONFIGUREOPTS', ' '.join(tokens))
    d.setVar('CONFIGUREOPT_SYSROOT', '')
}

# Skip autoreconf for commercial bundles and rely on bundled configure script
# If configure script doesn't exist, generate it from configure.ac/configure.in
do_configure() {
    bbnote "Commercial bundle detected, checking for configure script"
    # Verify source directory exists
    if [ ! -d "${S}" ]; then
        bbwarn "Expected source directory ${S} doesn't exist"
        bbwarn "Searching WORKDIR for extracted bundle directories..."
        # Look for directories that might contain configure files
        found_dirs=$(find ${WORKDIR} -maxdepth 3 -type d 2>/dev/null | grep -v "^${WORKDIR}$" | head -20)
        if [ -n "${found_dirs}" ]; then
            bbwarn "Found directories in WORKDIR:"
            for dir in ${found_dirs}; do
                if [ -f "${dir}/configure" ] || [ -f "${dir}/configure.ac" ] || [ -f "${dir}/configure.in" ]; then
                    bbwarn "  ${dir} (contains configure files!)"
                else
                    bbwarn "  ${dir}"
                    # List first few files in this directory
                    file_count=$(find "${dir}" -maxdepth 1 -type f 2>/dev/null | wc -l)
                    dir_count=$(find "${dir}" -maxdepth 1 -type d 2>/dev/null | wc -l)
                    bbwarn "    -> Contains ${file_count} files and ${dir_count} directories"
                fi
            done
        fi
        bbfatal "Source directory ${S} does not exist. Check bundle extraction and WOLFSSL_SRC setting."
    fi
    
    # Check if directory is empty
    if [ -z "$(ls -A ${S} 2>/dev/null)" ]; then
        bbwarn "Source directory ${S} exists but is empty"
        bbwarn "This may indicate the bundle extraction failed or the bundle is empty"
        bbwarn "Checking if extraction actually ran..."
        # Check extraction logs
        if [ -f "${WORKDIR}/temp/log.do_commercial_extract" ]; then
            bbwarn "Extraction log exists, checking for errors..."
            tail -20 "${WORKDIR}/temp/log.do_commercial_extract" | grep -i "error\|fatal\|extracted" || true
        fi
        bbfatal "Source directory ${S} is empty. Bundle extraction may have failed or bundle structure is incorrect."
    fi
    
    # List what's actually in the source directory
    bbnote "Contents of source directory ${S}:"
    ls -la ${S} 2>&1 | head -30 || true
    file_count=$(find ${S} -maxdepth 1 -type f 2>/dev/null | wc -l)
    dir_count=$(find ${S} -maxdepth 1 -type d 2>/dev/null | wc -l)
    bbnote "Source directory contains ${file_count} files and ${dir_count} directories"
    # Ensure libtool sysroot option is stripped (not accepted by commercial bundles)
    unset CONFIGUREOPT_SYSROOT
    CONFIGUREOPTS="$(echo ${CONFIGUREOPTS} | sed 's/--with-libtool-sysroot=[^ ]*//g')"
    if [ -e "${S}/configure.ac" ] && [ ! -f "${S}/stamp-h.in" ] && \
       grep -q "AC_CONFIG_FILES(\\[stamp-h\\]" "${S}/configure.ac"; then
        bbnote "stamp-h.in missing; generating stub for preconfigured commercial source"
        echo "timestamp" > "${S}/stamp-h.in"
    fi
    
    # If configure script doesn't exist, try to generate it
    if [ ! -e "${CONFIGURE_SCRIPT}" ]; then
        bbnote "configure script not found at ${CONFIGURE_SCRIPT}, attempting to generate it"
        bbnote "Source directory S=${S}"
        bbnote "Contents of source directory:"
        ls -la ${S} 2>&1 | head -20 || true
        # Check if configure.ac/in might be in a subdirectory
        if [ ! -e "${S}/configure.ac" ] && [ ! -e "${S}/configure.in" ]; then
            bbnote "Checking subdirectories for configure.ac/configure.in:"
            find ${S} -maxdepth 2 -name "configure.ac" -o -name "configure.in" 2>/dev/null | head -5 || true
        fi
        if [ -e "${S}/configure.ac" ] || [ -e "${S}/configure.in" ]; then
            # Check if autogen.sh exists and is not a stub
            if [ -f "${S}/autogen.sh" ] && [ -x "${S}/autogen.sh" ]; then
                # Check if it's a stub (commercial bundle stub just exits)
                if ! grep -q "Commercial bundle" "${S}/autogen.sh" 2>/dev/null; then
                    bbnote "Running autogen.sh to generate configure script"
                    cd ${S}
                    ./autogen.sh || bbfatal "autogen.sh failed to generate configure script"
                else
                    bbnote "autogen.sh is a stub, using autoreconf instead"
                    cd ${S}
                    autoreconf -fvi || bbfatal "autoreconf failed to generate configure script"
                fi
            # Otherwise try autoreconf
            elif command -v autoreconf >/dev/null 2>&1; then
                bbnote "Running autoreconf to generate configure script"
                cd ${S}
                autoreconf -fvi || bbfatal "autoreconf failed to generate configure script"
            else
                bbfatal "configure script not found at ${CONFIGURE_SCRIPT} and cannot generate it (no autogen.sh or autoreconf available)"
            fi
        else
            # Last resort: search deeper in the directory tree for configure files
            bbwarn "configure.ac/configure.in not found in ${S}, searching subdirectories..."
            found_configure_ac=$(find ${S} -type f -name "configure.ac" 2>/dev/null | head -1)
            found_configure_in=$(find ${S} -type f -name "configure.in" 2>/dev/null | head -1)
            if [ -n "${found_configure_ac}" ] || [ -n "${found_configure_in}" ]; then
                configure_file="${found_configure_ac:-${found_configure_in}}"
                configure_dir=$(dirname "${configure_file}")
                bbwarn "Found configure.ac/in in subdirectory: ${configure_dir}"
                bbwarn "This may indicate the bundle structure is different than expected."
                bbwarn "You may need to adjust WOLFSSL_SRC or check the bundle structure."
                bbfatal "configure script not found at ${CONFIGURE_SCRIPT}. Found configure.ac/in in ${configure_dir} but expected in ${S}. Check bundle structure."
            else
                bbfatal "configure script not found at ${CONFIGURE_SCRIPT} and no configure.ac/configure.in found anywhere in source tree"
            fi
        fi
    fi
    
    if [ -e "${CONFIGURE_SCRIPT}" ]; then
        oe_runconf
    else
        bbfatal "configure script not found at ${CONFIGURE_SCRIPT} after generation attempt"
    fi
}

# Task to create stub autogen.sh for commercial bundles
do_commercial_stub_autogen() {
    if [ "${COMMERCIAL_BUNDLE_ENABLED}" != "1" ]; then
        bbnote "Commercial bundle disabled; skipping autogen stub."
        exit 0
    fi

    if [ ! -d "${S}" ]; then
        bbwarn "Source directory ${S} missing before autogen stub; skipping."
        exit 0
    fi

    # Commercial bundles are pre-configured and don't need autogen.sh
    # Create a no-op autogen.sh to prevent automatic execution
    if [ ! -f ${S}/autogen.sh ]; then
        echo '#!/bin/sh' > ${S}/autogen.sh
        echo '# Commercial bundle - pre-configured, no autogen needed' >> ${S}/autogen.sh
        echo 'exit 0' >> ${S}/autogen.sh
        chmod +x ${S}/autogen.sh
        bbplain "Created stub autogen.sh for commercial bundle"
    else
        bbplain "Replacing existing autogen.sh with stub for commercial bundle"
        echo '#!/bin/sh' > ${S}/autogen.sh
        echo '# Commercial bundle - pre-configured, no autogen needed' >> ${S}/autogen.sh
        echo 'exit 0' >> ${S}/autogen.sh
        chmod +x ${S}/autogen.sh
    fi
}

# Add task after unpack (or commercial_extract for 7z), before configure
addtask commercial_stub_autogen after do_unpack before do_configure
