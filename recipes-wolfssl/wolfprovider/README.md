# wolfProvider

The `wolfprovider` recipe enables the integration of wolfSSL's cryptographic functionalities into OpenSSL through a custom provider mechanism. This integration allows applications using OpenSSL to leverage wolfSSL's advanced cryptographic algorithms, combining wolfSSL's lightweight and performance-optimized cryptography with OpenSSL's extensive API and capabilities. `wolfprovider` is designed for easy integration into Yocto-based systems, ensuring a seamless blend of security and performance ideal for embedded and constrained environments.

The `wolfproviderenv` yocto package provides the base testing tools for wolfProvider.

- **`wolfproviderverify`** - Quick provider load verification test
- **`wolfproviderenv`** - Environment setup script that orchestrates all tests

The `wolfprovidertest` yocto package provides the unit test suite for wolfProvider.

- **`wolfprovidertest`** - Comprehensive unit test suite from wolfProvider

## Getting Started

### Prerequisites

- A functioning Yocto Project environment (Kirkstone or later recommended)
- OpenSSL 3.0 or later, supporting the provider interface (Come by default with Kirkstone or later)
- Access to the `meta-wolfssl` repository

### Integrating wolfprovider with Yocto

1. **Clone the meta-wolfssl repository**:

    Clone the `meta-wolfssl` repository into your Yocto project's sources directory if not already included in your project.

    ```sh
    git clone https://github.com/wolfSSL/meta-wolfssl.git
    ```

2. **Include meta-wolfssl in your bblayers.conf**:

    Add `meta-wolfssl` to your `bblayers.conf` file to incorporate it into your build environment.

    ```bitbake
    BBLAYERS ?= " \
      ...
      /path/to/meta-wolfssl \
      ...
    "
    ```

3. **Add wolfprovider to your image**:

    Modify your image recipe or `local.conf` file to include `wolfprovider`, `wolfssl`, `openssl`, `openssl-bin`, and `wolfproviderenv`. You will only need `openssl-bin` and `wolfproviderenv` if you want to use and test with our included example and conf file. Add `wolfprovidertest` to test the unit test as well.

    For yocto kirkstone or newer:
    ```
    IMAGE_INSTALL:append = "wolfprovider wolfssl openssl openssl-bin wolfproviderenv wolfprovidertest"
    ```

    For yocto dunfell or earlier:
    ```
    IMAGE_INSTALL_append = "wolfprovider wolfssl openssl openssl-bin wolfproviderenv wolfprovidertest"
    ```

4. **Build Your Image**:

    With the `meta-wolfssl` layer added and the necessary packages included in your image configuration, proceed to build your Yocto image as usual.

    ```sh
    bitbake <your_image_recipe_name>
    ```

### Testing wolfprovider

After building and deploying your image to the target device, you can test `wolfprovider` functionality using the provided test programs.

#### Quick Provider Verification

For a quick check that the provider loads correctly:

```sh
wolfproviderverify
```

Expected output:
```
Custom provider 'libwolfprov' loaded successfully.
```

#### Comprehensive Environment Test

To run the complete test workflow with environment setup:

```sh
wolfproviderenv
```

This script:
1. Sets up OPENSSL_MODULES and LD_LIBRARY_PATH
2. Creates OpenSSL configuration for wolfProvider
3. Runs `wolfprovverify` (quick check)
4. Lists active OpenSSL providers
5. Runs `wolfprovidertest` (full unit tests)

#### Unit Test Suite

To run just the comprehensive unit tests:

```sh
wolfprovidertest
```

This runs the actual wolfProvider unit test suite with full coverage of all cryptographic operations.

#### Expected Output

Running `wolfproviderenv` should show:
- Provider loaded successfully message
- List of active providers including libwolfprov
- Unit test results (PASSED or status)
- OpenSSL configuration confirmation

Example Output from `wolfproviderenv` should look something like this:
```
==========================================
wolfProvider Test Environment Setup
==========================================

Environment Variables:
  OPENSSL_MODULES: /usr/lib/ssl-3/modules
  LD_LIBRARY_PATH: /usr/lib:/lib
  OPENSSL_CONF: /opt/wolfprovider-configs/wolfprovider.conf

==========================================
Test 1: Provider Load Verification
==========================================
Custom provider 'libwolfprov' loaded successfully.
Passed!

==========================================
Test 2: OpenSSL Provider List
==========================================
Providers:
  libwolfprov
    name: wolfSSL Provider
    version: 1.1.0
    status: active
    build info: wolfSSL 5.8.2
    ...

==========================================
Test 3: wolfProvider Unit Tests
==========================================
Running comprehensive unit test suite...
[Unit test output...]
Passed!

Tests completed.
==========================================
```

### Documentation and Support

For further information about `wolfprovider` and `wolfssl`, visit the [wolfSSL Documentation](https://www.wolfssl.com/docs/) and the [wolfProvider Github](https://www.github.com/wolfSSL/wolfprovider). If you encounter issues or require support regarding the integration of `wolfprovider` with Yocto, feel free to reach out through [wolfSSL Support](support@wolfssl.com).
