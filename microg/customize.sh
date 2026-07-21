#!/system/bin/sh

SKIPUNZIP=0
PRODUCT="$MODPATH/system/product"

ui_print() { echo "$1"; }

print_banner() {
    if [ -f "$MODPATH/common/ascii_banner.txt" ]; then
        while IFS= read -r L; do echo "$L"; done < "$MODPATH/common/ascii_banner.txt"
    fi
}

GP() { getprop "$1" 2>/dev/null; }

print_banner

if [ "$BOOTMODE" != "true" ]; then
    abort "! Install from the Magisk app, not recovery/TWRP."
fi

if [ -z "$MAGISK_VER_CODE" ] || [ "$MAGISK_VER_CODE" -lt 24000 ]; then
    abort "! Magisk 24.0+ required (found $MAGISK_VER_CODE)."
fi

API=$(GP ro.build.version.sdk)
if [ -z "$API" ] || [ "$API" -lt 26 ]; then
    abort "! Android 8.0 (API 26) or newer required."
fi

if [ -f /system/etc/grapheneos-release ] || GP ro.build.fingerprint | grep -qi grapheneos; then
    abort "! GrapheneOS does not support signature spoofing. Not installing."
fi

REAL_GMS=0
GMS_PATH=$(pm path com.google.android.gms 2>/dev/null | head -1 | sed 's/^package://')
if [ -n "$GMS_PATH" ]; then
    pm dump com.google.android.gms 2>/dev/null | grep -qi 'fake_package_signature' || REAL_GMS=1
fi

mask_stock_pkg() {
    pkg="$1"
    p=$(pm path "$pkg" 2>/dev/null | head -1 | sed 's/^package://')
    [ -n "$p" ] || return 0
    pm dump "$pkg" 2>/dev/null | grep -qi 'fake_package_signature' && return 0
    d=$(dirname "$p")
    case "$d" in
        /system/product/*)    t="$MODPATH/system/product${d#/system/product}" ;;
        /product/*)           t="$MODPATH/system/product${d#/product}" ;;
        /system/system_ext/*) t="$MODPATH/system/system_ext${d#/system/system_ext}" ;;
        /system_ext/*)        t="$MODPATH/system/system_ext${d#/system_ext}" ;;
        /system/*)            t="$MODPATH/system${d#/system}" ;;
        *) return 0 ;;
    esac
    mkdir -p "$t" && : > "$t/.replace"
}

if [ "$REAL_GMS" -eq 1 ]; then
    mask_stock_pkg com.google.android.gms
    mask_stock_pkg com.android.vending
    mask_stock_pkg com.google.android.gsf
fi

if [ "$API" -lt 28 ] || { [ ! -d /product ] && [ ! -L /system/product ]; }; then
    mkdir -p "$MODPATH/system/priv-app" "$MODPATH/system/app" \
             "$MODPATH/system/etc/permissions" "$MODPATH/system/etc/sysconfig" \
             "$MODPATH/system/etc/default-permissions"
    cp -a "$PRODUCT/priv-app/." "$MODPATH/system/priv-app/" 2>/dev/null
    cp -a "$PRODUCT/app/." "$MODPATH/system/app/" 2>/dev/null
    cp -a "$PRODUCT/etc/permissions/." "$MODPATH/system/etc/permissions/" 2>/dev/null
    cp -a "$PRODUCT/etc/sysconfig/." "$MODPATH/system/etc/sysconfig/" 2>/dev/null
    cp -a "$PRODUCT/etc/default-permissions/." "$MODPATH/system/etc/default-permissions/" 2>/dev/null
    if [ -d "$PRODUCT" ]; then
        ( cd "$PRODUCT" && find . -name .replace -type f 2>/dev/null ) | while IFS= read -r r; do
            sub=${r#./}
            mkdir -p "$MODPATH/system/$(dirname "$sub")"
            : > "$MODPATH/system/$sub"
        done
    fi
    rm -rf "$MODPATH/system/product"
fi

SPOOF="unknown"
if GP ro.calyxos.version | grep -q . ; then SPOOF="yes"; fi
if GP ro.iode.version    | grep -q . ; then SPOOF="yes"; fi
if GP ro.e.version       | grep -q . ; then SPOOF="yes"; fi
if GP ro.divest.version  | grep -q . ; then SPOOF="yes"; fi
if [ "$SPOOF" = "unknown" ] && GP ro.lineage.version | grep -q . ; then SPOOF="likely"; fi
if echo "$SPOOF" | grep -qi unknown; then
    ui_print "  microG needs ROM signature spoofing. If microG Self-Check shows it red after reboot, this ROM does not provide it."
fi

set_perm_recursive "$MODPATH/system" 0 0 0755 0644
