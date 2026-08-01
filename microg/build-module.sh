#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

OFFICIAL_MICROG_KEY="9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165"
AURORA_STORE_KEY="5c83c7672b929955dc0a1db89a5e6ae4389e2eae7ec939956041694e5815f532"
AURORA_SERVICES_KEY="e027daef049840a924330edf22641fd93294620220fa488645c9eb7b20f7e825"

VER=$(grep '^version=' module.prop | cut -d= -f2)
ZIPNAME="DresOS-microG-${VER//./_}.zip"
BUILD="build"
PERMS_XML="system/product/etc/permissions/privapp-permissions-dresos-microg.xml"

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

for a in GmsCore Companion GsfProxy; do
    [ -f "$COREDIR/$a.apk" ] || { echo "! missing $COREDIR/$a.apk"; echo "  run refresh-upstream.sh first (see apk/README.txt)"; exit 1; }
done

for a in GmsCore Companion GsfProxy; do
    fp=$(read_cert "$COREDIR/$a.apk")
    if [ "$fp" != "$OFFICIAL_MICROG_KEY" ]; then
        echo "! $COREDIR/$a.apk is NOT signed with the official microG key."
        echo "!   expected: $OFFICIAL_MICROG_KEY"
        echo "!   found:    ${fp:-<none>}"
        echo "! ROM signature spoofing will not activate with this APK."
        echo "! If 'found' is empty the APK has no v1 signature block to read. Aborting."
        exit 1
    fi
done

check_optional_key() {
    local file="$1" expect="$2" name="$3" fp
    [ -f "$file" ] || return 0
    fp=$(read_cert "$file")
    if [ "$fp" != "$expect" ]; then
        echo "! $file is not signed with the expected $name key."
        echo "!   expected: $expect"
        echo "!   found:    ${fp:-<none>}"
        echo "! Refusing to stage an unverified APK as a system app. Aborting."
        exit 1
    fi
}

check_optional_key apk/AuroraStore.apk    "$AURORA_STORE_KEY"    "Aurora Store"
check_optional_key apk/AuroraServices.apk "$AURORA_SERVICES_KEY" "Aurora Services"

regen_allowlist() {
    command -v aapt >/dev/null 2>&1 || { echo "  (aapt not found; using committed allowlist as-is)"; return 0; }
    command -v python3 >/dev/null 2>&1 || { echo "  (python3 not found; using committed allowlist as-is)"; return 0; }
    local gms ven gsf aus
    perms_of() { aapt dump permissions "$1" 2>/dev/null | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u; }
    gms=$(perms_of apk/GmsCore.apk)
    ven=$(perms_of apk/Companion.apk)
    gsf=$(perms_of apk/GsfProxy.apk)
    aus=$(perms_of apk/AuroraServices.apk)
    [ -n "$gms" ] || { echo "  (could not read GmsCore permissions; using committed allowlist)"; return 0; }
    GMS_PERMS="$gms" VEN_PERMS="$ven" GSF_PERMS="$gsf" AUS_PERMS="$aus" python3 - "$PERMS_XML" <<'PY'
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
    extra = sorted(p for p in extra if p)
    if not extra:
        return 0
    m = block_of(pkg)
    if not m:
        lines = "".join('        <permission name="%s"/>\n' % p for p in extra)
        block = '    <privapp-permissions package="%s">\n%s    </privapp-permissions>\n' % (pkg, lines)
        if "</permissions>" not in xml:
            return 0
        xml = xml.replace("</permissions>", block + "</permissions>", 1)
        return len(extra)
    head, body, tail = m.group(1), m.group(2), m.group(3)
    have = set(re.findall(r'name="([^"]+)"', body))
    add = sorted(p for p in extra if p and p not in have)
    if not add:
        return 0
    indent = "        "
    lines = "".join('%s<permission name="%s"/>\n' % (indent, p) for p in add)
    new_body = body.rstrip("\n") + "\n" + lines + "    "
    xml = xml.replace(head + body + tail, head + new_body + tail, 1)
    return len(add)

for pkg, var in (("com.google.android.gms","GMS_PERMS"),
                 ("com.android.vending","VEN_PERMS"),
                 ("com.google.android.gsf","GSF_PERMS"),
                 ("com.aurora.services","AUS_PERMS")):
    merge(pkg, set(filter(None, os.environ.get(var,"").splitlines())))
open(path, "w", encoding="utf-8").write(xml)
PY
}
regen_allowlist

rm -rf "$BUILD" "$ZIPNAME"
mkdir -p "$BUILD"
cp -a module.prop customize.sh action.sh post-fs-data.sh service.sh \
      update.json README.md CHANGELOG.md "$BUILD"/
cp -a META-INF common system "$BUILD"/
mkdir -p "$BUILD/system/product/priv-app/GmsCore" \
         "$BUILD/system/product/priv-app/Companion" \
         "$BUILD/system/product/priv-app/GsfProxy"
cp "$COREDIR/GmsCore.apk"   "$BUILD/system/product/priv-app/GmsCore/GmsCore.apk"
cp "$COREDIR/Companion.apk" "$BUILD/system/product/priv-app/Companion/Companion.apk"
cp "$COREDIR/GsfProxy.apk"  "$BUILD/system/product/priv-app/GsfProxy/GsfProxy.apk"

if [ -f apk/AuroraServices.apk ]; then
    mkdir -p "$BUILD/system/product/priv-app/AuroraServices"
    cp apk/AuroraServices.apk "$BUILD/system/product/priv-app/AuroraServices/AuroraServices.apk"
fi
if [ -f apk/AuroraStore.apk ]; then
    mkdir -p "$BUILD/system/product/app/AuroraStore"
    cp apk/AuroraStore.apk "$BUILD/system/product/app/AuroraStore/AuroraStore.apk"
fi

( cd "$BUILD" && zip -r -q -X "../$ZIPNAME" . -x "*.DS_Store" "._*" )
rm -rf "$BUILD"
