# wolfProvider Replace-Default Mode Class
#
# Inherit this class in your image recipe to enable replace-default mode
# where wolfProvider replaces OpenSSL's default provider.
#
# Usage in recipes-core/images/YOUR-IMAGE/your-image.bb:
#   inherit wolfprovider-replace-default
#
# This class sets WOLFPROVIDER_REPLACE_DEFAULT = "1" at parse time,
# making it available to all recipes (OpenSSL, wolfProvider, etc.)

WOLFPROVIDER_REPLACE_DEFAULT = "1"

# Tell recipes that wolfProvider is being used (needed for wolfprovider checks)
WOLFSSL_FEATURES = "wolfprovider"

