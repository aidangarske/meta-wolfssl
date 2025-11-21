#!/bin/bash

echo "=========================================="
echo "Algorithm Availability Check"
echo "=========================================="
echo ""

# Setup environment
if [ -f /usr/bin/wolfproviderenv ]; then
    source /usr/bin/wolfproviderenv > /dev/null 2>&1
fi

echo "1. Checking OpenSSL provider:"
echo "----------------------------------------"
openssl list -providers 2>/dev/null
echo ""

echo "2. Checking digest algorithms:"
echo "----------------------------------------"
DIGEST_ALGOS=$(openssl list -digest-algorithms 2>/dev/null)
echo "$DIGEST_ALGOS"
echo ""

echo "3. Checking cipher algorithms:"
echo "----------------------------------------"
CIPHER_ALGOS=$(openssl list -cipher-algorithms 2>/dev/null)
echo "$CIPHER_ALGOS"
echo ""

echo "4. Checking public key algorithms:"
echo "----------------------------------------"
PUBKEY_ALGOS=$(openssl list -public-key-algorithms 2>/dev/null)
echo "$PUBKEY_ALGOS"
echo ""

echo "5. Checking for non-FIPS algorithms:"
echo "----------------------------------------"
NON_FIPS_ALGOS=(
    "MD5" "MD4" 
    "RC4" "RC2"
    "DES" "DES-EDE3" "DES-EDE" "DESX"
    "BLOWFISH" "BF"
    "CAST" "CAST5" "CAST128"
    "IDEA"
    "SEED"
    "CAMELLIA" "CAMELLIA128" "CAMELLIA256"
    "ARIA" "ARIA128" "ARIA256"
    "SM4"
    "CHACHA20" "POLY1305" "CHACHA20-POLY1305"
    "SIPHASH"
    "SM2" "SM3"
)

NON_FIPS_FOUND=0
for algo in "${NON_FIPS_ALGOS[@]}"; do
    if echo "$DIGEST_ALGOS" | grep -qi "$algo"; then
        echo "  ✗ WARNING: Non-FIPS digest algorithm '$algo' is available"
        NON_FIPS_FOUND=1
    fi
    if echo "$CIPHER_ALGOS" | grep -qi "$algo"; then
        echo "  ✗ WARNING: Non-FIPS cipher algorithm '$algo' is available"
        NON_FIPS_FOUND=1
    fi
    if echo "$PUBKEY_ALGOS" | grep -qi "$algo"; then
        echo "  ✗ WARNING: Non-FIPS public key algorithm '$algo' is available"
        NON_FIPS_FOUND=1
    fi
done

if [ $NON_FIPS_FOUND -eq 0 ]; then
    echo "  ✓ No non-FIPS algorithms detected"
fi

echo ""
echo "6. Checking for FIPS-approved algorithms (should be available):"
echo "----------------------------------------"
FIPS_ALGOS=(
    "AES" "AES-128" "AES-192" "AES-256"
    "SHA" "SHA1" "SHA-1" "SHA256" "SHA-256" "SHA384" "SHA-384" "SHA512" "SHA-512" "SHA-224" "SHA-512/224" "SHA-512/256"
    "HMAC" "HMAC-SHA1" "HMAC-SHA256" "HMAC-SHA384" "HMAC-SHA512"
    "RSA" "DSA" "ECDSA" "ECDH" "DH" "FFC"
    "GCM" "CCM" "CTR" "CBC" "OFB" "CFB"
)

FIPS_FOUND=0
for algo in "${FIPS_ALGOS[@]}"; do
    if echo "$DIGEST_ALGOS" | grep -qi "$algo"; then
        echo "  ✓ FIPS algorithm '$algo' is available"
        FIPS_FOUND=1
    elif echo "$CIPHER_ALGOS" | grep -qi "$algo"; then
        echo "  ✓ FIPS algorithm '$algo' is available"
        FIPS_FOUND=1
    elif echo "$PUBKEY_ALGOS" | grep -qi "$algo"; then
        echo "  ✓ FIPS algorithm '$algo' is available"
        FIPS_FOUND=1
    fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
if [ $NON_FIPS_FOUND -eq 0 ]; then
    echo "✓ PASS: No non-FIPS algorithms detected"
    exit 0
else
    echo "✗ FAIL: Non-FIPS algorithms detected - OpenSSL should be patched to disable them"
    exit 1
fi

