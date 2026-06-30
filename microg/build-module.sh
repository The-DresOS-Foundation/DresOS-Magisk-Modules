#!/usr/bin/env bash
##############################################################################
#  DresOS microG  build-module.sh
#
#  Assembles the flashable Magisk module zip from the committed source plus
#  the officially signed APKs in ./apk/ (gitignored: GmsCore alone exceeds
#  GitHub's 100 MB per-file limit).
#
#  Usage:   ./build-module.sh
#  Output:  ./DresOS-microG-v<version>.zip  + its SHA-256
#
#  Guards:
#    - refuses to build unless the three microG core APKs carry the official
#      microG signing key (prevents the "ROM never spoofs, wrong key" bug);
#    - regenerates the privileged-permission allowlist from the actual bundled
#      manifests, merged with the committed baseline, so a microG update that
#      adds a new privileged permission can never silently reintroduce a
#      bootloop (the allowlist always covers every permission the APKs request);
#    - Aurora is optional: if its APKs are absent the core microG module still
#      builds.
##############################################################################
set -euo pipefail
cd "$(dirname "$0")"

OFFICIAL_MICROG_KEY="9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165"

VER=$(grep '^version=' module.prop | cut -d= -f2)
ZIPNAME="DresOS-microG-${VER//./_}.zip"
BUILD="build"
PERMS_XML="system/product/etc/permissions/privapp-permissions-dresos-microg.xml"

# The Google-signed "stock" flavor was removed in v3.1.1: grafting Google's
# certificate onto microG cannot make a verifiable APK without Google's private
# key, so it failed to install on modern Android. microG on stock now relies on
# signature spoofing (LSPosed + FakeGApps, or a spoofing-capable ROM); see README.
if [ "${GOOGLE_SIGNED:-}" = "1" ]; then
    echo "  note: the GOOGLE_SIGNED stock flavor was removed in v3.1.1."
    echo "        Building the standard spoofing flavor. See README for stock setup."
fi
FLAVOR="microg-key"
COREDIR="apk"

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

read_cert() { apk_cert_sha256 "$1"; }

echo "Building DresOS microG $VER"

# 1. required core APKs present?
for a in GmsCore Companion GsfProxy; do
    [ -f "$COREDIR/$a.apk" ] || { echo "! missing $COREDIR/$a.apk"; echo "  run refresh-upstream.sh first (see apk/README.txt)"; exit 1; }
done

# 2. verify the core trio is signed with the official microG key, so ROM
#    signature spoofing will activate for it.
for a in GmsCore Companion GsfProxy; do
    fp=$(read_cert "$COREDIR/$a.apk")
    if [ "$fp" != "$OFFICIAL_MICROG_KEY" ]; then
        echo "! $COREDIR/$a.apk is NOT signed with the official microG key."
        echo "!   expected: $OFFICIAL_MICROG_KEY"
        echo "!   found:    ${fp:-<none>}"
        echo "! ROM signature spoofing will not activate with this APK. Aborting."
        exit 1
    fi
    echo "  verified official microG key: $a.apk"
done

# 3. regenerate the privileged-permission allowlist from the real manifests,
#    merged with the committed baseline. Needs aapt + python3; if either is
#    missing we fall back to the committed baseline unchanged.
regen_allowlist() {
    command -v aapt >/dev/null 2>&1 || { echo "  (aapt not found; using committed allowlist as-is)"; return 0; }
    command -v python3 >/dev/null 2>&1 || { echo "  (python3 not found; using committed allowlist as-is)"; return 0; }
    local gms ven
    gms=$(aapt dump permissions apk/GmsCore.apk 2>/dev/null | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u)
    ven=$(aapt dump permissions apk/Companion.apk 2>/dev/null | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u)
    [ -n "$gms" ] || { echo "  (could not read GmsCore permissions; using committed allowlist)"; return 0; }
    GMS_PERMS="$gms" VEN_PERMS="$ven" python3 - "$PERMS_XML" <<'PY'
import os, re, sys
path = sys.argv[1]
xml = open(path, encoding="utf-8").read()

def perms_for(pkg, block):
    return set(re.findall(r'name="([^"]+)"', block))

def block_of(pkg):
    m = re.search(r'(<privapp-permissions package="%s">)(.*?)(</privapp-permissions>)' % re.escape(pkg), xml, re.S)
    return m

def merge(pkg, extra):
    global xml
    m = block_of(pkg)
    if not m:
        return 0
    head, body, tail = m.group(1), m.group(2), m.group(3)
    have = set(re.findall(r'name="([^"]+)"', body))
    add = sorted(p for p in extra if p and p not in have)
    if not add:
        return 0
    indent = "        "
    lines = "".join('%s<permission name="%s"/>\n' % (indent, p) for p in add)
    # keep existing body, append new permissions before the closing tag
    new_body = body.rstrip("\n") + "\n" + lines + "    "
    xml = xml.replace(head + body + tail, head + new_body + tail, 1)
    return len(add)

gms_extra = set(filter(None, os.environ.get("GMS_PERMS","").splitlines()))
ven_extra = set(filter(None, os.environ.get("VEN_PERMS","").splitlines()))
a = merge("com.google.android.gms", gms_extra)
b = merge("com.android.vending", ven_extra)
open(path, "w", encoding="utf-8").write(xml)
print("  allowlist merge: +%d GmsCore, +%d Companion permission(s) from manifests" % (a, b))
PY
}
regen_allowlist

# 4. assemble tree (core + boot scripts always; Aurora only if present)
rm -rf "$BUILD" "$ZIPNAME"
mkdir -p "$BUILD"
cp -a module.prop customize.sh action.sh post-fs-data.sh service.sh \
      update.json README.md CHANGELOG.md "$BUILD"/
cp -a META-INF common system "$BUILD"/
printf '%s\n' "$FLAVOR" > "$BUILD/flavor"   # read by customize.sh / action.sh
mkdir -p "$BUILD/system/product/priv-app/GmsCore" \
         "$BUILD/system/product/priv-app/Companion" \
         "$BUILD/system/product/priv-app/GsfProxy"
cp "$COREDIR/GmsCore.apk"   "$BUILD/system/product/priv-app/GmsCore/GmsCore.apk"
cp "$COREDIR/Companion.apk" "$BUILD/system/product/priv-app/Companion/Companion.apk"
cp "$COREDIR/GsfProxy.apk"  "$BUILD/system/product/priv-app/GsfProxy/GsfProxy.apk"

if [ -f apk/AuroraServices.apk ]; then
    mkdir -p "$BUILD/system/product/priv-app/AuroraServices"
    cp apk/AuroraServices.apk "$BUILD/system/product/priv-app/AuroraServices/AuroraServices.apk"
    echo "  included Aurora Services"
else
    echo "  Aurora Services not present; skipping (optional)"
fi
if [ -f apk/AuroraStore.apk ]; then
    mkdir -p "$BUILD/system/product/app/AuroraStore"
    cp apk/AuroraStore.apk "$BUILD/system/product/app/AuroraStore/AuroraStore.apk"
    echo "  included Aurora Store"
else
    echo "  Aurora Store not present; skipping (optional)"
fi

# 5. zip with files at the root
( cd "$BUILD" && zip -r -q -X "../$ZIPNAME" . -x "*.DS_Store" "._*" )
rm -rf "$BUILD"

echo
echo "Built: $ZIPNAME"
ls -lh "$ZIPNAME" | awk '{print "  size: "$5}'
echo "  sha256: $(openssl dgst -sha256 "$ZIPNAME" | sed 's/.*= //')"
echo
echo "Attach $ZIPNAME to a GitHub Release tagged microg-$VER so update.json resolves."
