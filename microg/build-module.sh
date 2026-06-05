#!/usr/bin/env bash
##############################################################################
#  DresOS microG  build-module.sh
#
#  Assembles the flashable Magisk module zip from the committed source plus
#  the officially signed APKs you drop into ./apk/ (those are gitignored
#  because GmsCore alone exceeds GitHub's 100 MB per-file limit).
#
#  Usage:   ./build-module.sh
#  Output:  ./DresOS-microG-v<version>.zip  + its SHA-256
#
#  The script REFUSES to build unless the three microG core APKs carry the
#  official microG signing key. That single check would have prevented the
#  whole "ROM never spoofs because the APK was signed with the wrong key"
#  class of bug.
##############################################################################
set -euo pipefail
cd "$(dirname "$0")"

OFFICIAL_MICROG_KEY="9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165"

VER=$(grep '^version=' module.prop | cut -d= -f2)
ZIPNAME="DresOS-microG-${VER//./_}.zip"
BUILD="build"

req() { command -v "$1" >/dev/null 2>&1 || { echo "! need '$1' on PATH"; exit 1; }; }
req unzip; req zip; req openssl; req find

apk_cert_sha256() {
    local apk="$1" tmp cert
    tmp=$(mktemp -d)
    unzip -o -q "$apk" "META-INF/*" -d "$tmp" 2>/dev/null || true
    cert=$(find "$tmp/META-INF" -iname '*.RSA' -o -iname '*.DSA' -o -iname '*.EC' 2>/dev/null | head -1)
    if [ -z "$cert" ]; then rm -rf "$tmp"; echo ""; return; fi
    openssl pkcs7 -inform DER -in "$cert" -print_certs 2>/dev/null \
      | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
      | tr 'A-F' 'a-f' | sed 's/.*=//; s/://g'
    rm -rf "$tmp"
}

echo "Building DresOS microG $VER"

# 1. required APKs present?
for a in GmsCore Companion GsfProxy AuroraStore AuroraServices DroidGuard; do
    [ -f "apk/$a.apk" ] || { echo "! missing apk/$a.apk (see apk/README.txt)"; exit 1; }
done

# 2. verify the microG core trio is officially signed
for a in GmsCore Companion GsfProxy; do
    fp=$(apk_cert_sha256 "apk/$a.apk")
    if [ "$fp" != "$OFFICIAL_MICROG_KEY" ]; then
        echo "! apk/$a.apk is NOT signed with the official microG key."
        echo "!   expected: $OFFICIAL_MICROG_KEY"
        echo "!   found:    ${fp:-<none>}"
        echo "! ROM signature spoofing will not activate with this APK. Aborting."
        exit 1
    fi
    echo "  verified official microG key: $a.apk"
done

# 3. assemble tree
rm -rf "$BUILD" "$ZIPNAME"
mkdir -p "$BUILD"
cp -a module.prop customize.sh action.sh update.json README.md CHANGELOG.md "$BUILD"/
cp -a META-INF common system "$BUILD"/
mkdir -p "$BUILD/system/product/priv-app/GmsCore" \
         "$BUILD/system/product/priv-app/Companion" \
         "$BUILD/system/product/priv-app/GsfProxy" \
         "$BUILD/system/product/priv-app/AuroraServices" \
         "$BUILD/system/product/app/AuroraStore" \
         "$BUILD/system/product/app/DroidGuard"
cp apk/GmsCore.apk        "$BUILD/system/product/priv-app/GmsCore/GmsCore.apk"
cp apk/Companion.apk      "$BUILD/system/product/priv-app/Companion/Companion.apk"
cp apk/GsfProxy.apk       "$BUILD/system/product/priv-app/GsfProxy/GsfProxy.apk"
cp apk/AuroraServices.apk "$BUILD/system/product/priv-app/AuroraServices/AuroraServices.apk"
cp apk/AuroraStore.apk    "$BUILD/system/product/app/AuroraStore/AuroraStore.apk"
cp apk/DroidGuard.apk     "$BUILD/system/product/app/DroidGuard/DroidGuard.apk"

# 4. zip with files at the root
( cd "$BUILD" && zip -r -q -X "../$ZIPNAME" . -x "*.DS_Store" "._*" )
rm -rf "$BUILD"

echo
echo "Built: $ZIPNAME"
ls -lh "$ZIPNAME" | awk '{print "  size: "$5}'
echo "  sha256: $(openssl dgst -sha256 "$ZIPNAME" | sed 's/.*= //')"
echo
echo "Attach $ZIPNAME to a GitHub Release tagged microg-$VER so update.json resolves."
