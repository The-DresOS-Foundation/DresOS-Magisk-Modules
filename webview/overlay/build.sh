#!/bin/sh
set -eu
OUT_APK="DresOSWebViewOverlay.apk"
KEYSTORE="release.keystore"
KEY_ALIAS="dresos"
KEY_PASS="dresos1"
FRAMEWORK_RES="/usr/share/android-framework-res/framework-res.apk"

for cmd in aapt2 zipalign apksigner keytool; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd not found in PATH." >&2; exit 1; }
done
[ -f "$FRAMEWORK_RES" ] || { echo "ERROR: framework-res.apk not found at $FRAMEWORK_RES" >&2; exit 1; }
[ -f "AndroidManifest.xml" ] && [ -d "res" ] || { echo "ERROR: run from the overlay/ directory." >&2; exit 1; }

if [ ! -f "$KEYSTORE" ]; then
    echo "  Generating signing key (one time)."
    keytool -genkeypair -keystore "$KEYSTORE" -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 -storepass "$KEY_PASS" -keypass "$KEY_PASS" \
        -validity 36500 \
        -dname "CN=DresOS, OU=Magisk Module, O=DresOperatingSystems, L=N/A, ST=N/A, C=N/A" \
        2>&1 | tail -2
fi

rm -rf build && mkdir -p build

echo "  Compiling resources."
aapt2 compile --dir res/ -o build/compiled.zip

echo "  Linking APK."
aapt2 link \
    -I "$FRAMEWORK_RES" \
    --manifest AndroidManifest.xml \
    --min-sdk-version 29 \
    --target-sdk-version 35 \
    -o build/unsigned.apk \
    build/compiled.zip

echo "  Aligning."
zipalign -f -p 4 build/unsigned.apk build/aligned.apk

echo "  Signing (v1+v2+v3)."
rm -f "$OUT_APK"
apksigner sign \
    --ks "$KEYSTORE" --ks-pass "pass:$KEY_PASS" --key-pass "pass:$KEY_PASS" \
    --ks-key-alias "$KEY_ALIAS" \
    --min-sdk-version 21 \
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
    --out "$OUT_APK" \
    build/aligned.apk

echo "  Verifying."
apksigner verify --min-sdk-version 21 "$OUT_APK" >/dev/null 2>&1 && echo "  Signature verified."

rm -rf build
echo ""
echo "  RRO built: $(pwd)/$OUT_APK"
ls -la "$OUT_APK"
