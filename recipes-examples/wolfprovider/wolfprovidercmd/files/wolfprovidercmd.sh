#!/bin/bash

# Setup for libwolfprov.so
mkdir -p /usr/lib/ssl-3/modules
if [ ! -L /usr/lib/ssl-3/modules/libwolfprov.so ]; then
    ln -s /usr/lib/libwolfprov.so.0.0.0 /usr/lib/ssl-3/modules/libwolfprov.so
fi

# Environment variables
export OPENSSL_MODULES=/usr/lib/ssl-3/modules
export LD_LIBRARY_PATH=/usr/lib:/lib:$LD_LIBRARY_PATH

# Configuration for wolfprovider
mkdir -p /opt/wolfprovider-configs
cat > /opt/wolfprovider-configs/wolfprovider.conf <<EOF
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
libwolfprov = libwolfprov_sect

[libwolfprov_sect]
activate = 1
EOF

export OPENSSL_CONF="/opt/wolfprovider-configs/wolfprovider.conf"

echo ""
echo "=========================================="
echo "wolfProvider Command-Line Tests"
echo "=========================================="
if [ -f /usr/share/wolfprovider-cmd-tests/scripts/cmd_test/do-cmd-tests.sh ]; then
    echo "Running command-line test suite..."
    echo ""
    
    # Set environment for cmd tests - use system-wide installations
    export WOLFSSL_ISFIPS=1 # openssl built without cfb which fips also is
    export OPENSSL_BIN=$(which openssl)
    export WOLFPROV_PATH=/usr/lib/ssl-3/modules
    export WOLFPROV_CONFIG=/opt/wolfprovider-configs/wolfprovider.conf
    
    # Set library paths for system-wide OpenSSL/wolfSSL
    export LD_LIBRARY_PATH=/usr/lib:/lib:$LD_LIBRARY_PATH
    export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:$PKG_CONFIG_PATH
    
    # Prevent env-setup from trying to find build directories
    export OPENSSL_DIR=/usr
    export WOLFSSL_DIR=/usr
    
    # Change to test directory and run
    (
        cd /usr/share/wolfprovider-cmd-tests/scripts/cmd_test
        bash ./do-cmd-tests.sh
    )
    CMD_TEST_RESULT=$?
    
    if [ $CMD_TEST_RESULT -eq 0 ]; then
        echo ""
        echo "Command-line tests passed!"
    else
        echo ""
        echo "Command-line tests failed! (exit code: $CMD_TEST_RESULT)"
    fi
else
    echo "Command-line tests not available. Install wolfprovider-cmd-tests to run them."
fi

echo ""
echo "=========================================="
echo "Command-line tests completed."
echo "=========================================="
