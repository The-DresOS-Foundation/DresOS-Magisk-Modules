#!/bin/sh

set -eu

if [ ! -f "module.prop" ]; then
    echo "ERROR: run this script from the webview/ directory." >&2
    exit 1
fi

VERSION=$(grep "^version=" module.prop | cut -d= -f2)
[ -z "$VERSION" ] && { echo "ERROR: could not read version from module.prop"; exit 1; }
OUT_ZIP="DresOS-WebView-$(echo "$VERSION" | tr '.' '_').zip"

RRO="overlay/DresOSWebViewOverlay.apk"
WV="apks/webview-arm64.apk"
WV32="apks/aosmium-arm32.apk"

for f in "$RRO" "$WV" "$WV32"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: missing required artifact: $f" >&2
        if [ "$f" = "$RRO" ]; then
            echo "  Build it with: (cd overlay && ./build.sh)" >&2
        elif [ "$f" = "$WV" ]; then
            echo "  Place the signed DresOS WebView arm64 APK at apks/webview-arm64.apk" >&2
        else
            echo "  Place the AOSmium 32-bit arm APK at apks/aosmium-arm32.apk" >&2
        fi
        exit 1
    fi
done

if command -v aapt >/dev/null 2>&1; then
    pkg=$(aapt dump badging "$WV" 2>/dev/null | grep "^package:" | head -1 | sed "s/^package: name='\([^']*\)'.*/\1/")
    if [ -n "$pkg" ] && [ "$pkg" != "org.dresos.webview" ]; then
        echo "ERROR: $WV has package name '$pkg', expected 'org.dresos.webview'." >&2
        exit 1
    fi
    pkg32=$(aapt dump badging "$WV32" 2>/dev/null | grep "^package:" | head -1 | sed "s/^package: name='\([^']*\)'.*/\1/")
    if [ -n "$pkg32" ] && [ "$pkg32" != "org.axpos.aosmium_wv" ]; then
        echo "ERROR: $WV32 has package name '$pkg32', expected 'org.axpos.aosmium_wv'." >&2
        exit 1
    fi
fi

STAGE=$(mktemp -d)
trap "rm -rf $STAGE" EXIT

echo "  Staging module tree."
cp module.prop      "$STAGE/"
cp customize.sh     "$STAGE/"
cp post-fs-data.sh  "$STAGE/"
cp service.sh       "$STAGE/"
cp uninstall.sh     "$STAGE/"
cp update.json      "$STAGE/"
cp CHANGELOG.md     "$STAGE/"
cp README.md        "$STAGE/"

mkdir -p "$STAGE/overlay" "$STAGE/webview"
cp "$RRO"  "$STAGE/overlay/DresOSWebViewOverlay.apk"
cp "$WV"   "$STAGE/webview/webview-arm64.apk"
cp "$WV32" "$STAGE/webview/aosmium-arm32.apk"

rm -f "$OUT_ZIP"
echo "  Building $OUT_ZIP"
( cd "$STAGE" && zip -qr9 "$OLDPWD/$OUT_ZIP" . )

echo ""
echo "  Module built: $(pwd)/$OUT_ZIP"
ls -lh "$OUT_ZIP"
echo ""
echo "  SHA256:"
sha256sum "$OUT_ZIP"
