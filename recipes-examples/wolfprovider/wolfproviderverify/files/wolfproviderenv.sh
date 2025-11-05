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

echo "=========================================="
echo "wolfProvider Test Environment Setup"
echo "=========================================="
echo ""
echo "Environment Variables:"
echo "  OPENSSL_MODULES: $OPENSSL_MODULES"
echo "  LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "  OPENSSL_CONF: $OPENSSL_CONF"
echo ""

# Test 1: Provider Verification
echo "=========================================="
echo "Test 1: Provider Load Verification"
echo "=========================================="
if wolfproviderverify; then
    echo "Passed!"
else
    echo "Failed!"
    exit 1
fi

# Test 2: Provider List
echo ""
echo "=========================================="
echo "Test 2: OpenSSL Provider List"
echo "=========================================="
openssl list -providers -verbose

# Test 3: Unit Tests
echo ""
echo "=========================================="
echo "Test 3: wolfProvider Unit Tests"
echo "=========================================="
if [ -f /usr/bin/wolfprovidertest ]; then
    echo "Running comprehensive unit test suite..."
    
    # Create .libs symlink structure so the test can find the provider
    mkdir -p /usr/lib/.libs
    ln -sf /usr/lib/libwolfprov.so.0.0.0 /usr/lib/.libs/libwolfprov.so 2>/dev/null || true
    
    # Also ensure library is findable via LD_LIBRARY_PATH and current directory
    mkdir -p /tmp/.libs
    ln -sf /usr/lib/libwolfprov.so.0.0.0 /tmp/.libs/libwolfprov.so 2>/dev/null || true
    
    # Run the test from /tmp where .libs is available, or set search path
    # The test looks for .libs/libwolfprov.so relative to its search paths
    (
        export LD_LIBRARY_PATH="/tmp:$LD_LIBRARY_PATH"
        cd /tmp
        wolfprovidertest
    )
    TEST_RESULT=$?
    
    if [ $TEST_RESULT -eq 0 ]; then
        echo "Passed!"
    else
        echo "Failed! (exit code: $TEST_RESULT)"
    fi
else
    echo "Unit test binary not found. This is expected if wolfProvider was built without tests."
fi

echo ""
echo "=========================================="
echo "Tests completed."
echo "=========================================="

