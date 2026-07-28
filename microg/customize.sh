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

data_copies_of() {
    pm path "$1" 2>/dev/null | sed 's/^package://' | grep -c '^/data/'
}

mask_stock_pkg() {
    pkg="$1"
    pm dump "$pkg" 2>/dev/null | grep -qi 'fake_package_signature' && return 0
    pm path "$pkg" 2>/dev/null | sed 's/^package://' | while IFS= read -r p; do
        [ -n "$p" ] || continue
        d=$(dirname "$p")
        case "$d" in
            /system/product/*)    t="$MODPATH/system/product${d#/system/product}" ;;
            /product/*)           t="$MODPATH/system/product${d#/product}" ;;
            /system/system_ext/*) t="$MODPATH/system/system_ext${d#/system/system_ext}" ;;
            /system_ext/*)        t="$MODPATH/system/system_ext${d#/system_ext}" ;;
            /system/*)            t="$MODPATH/system${d#/system}" ;;
            *) continue ;;
        esac
        mkdir -p "$t" && : > "$t/.replace"
    done
}

if [ "$REAL_GMS" -eq 1 ]; then
    DATA_COPIES=0
    for gp in com.google.android.gms com.android.vending com.google.android.gsf; do
        DATA_COPIES=$((DATA_COPIES + $(data_copies_of "$gp")))
    done
    if [ "$DATA_COPIES" -gt 0 ]; then
        ui_print " "
        ui_print "! Google Play Services has updates installed in the data partition."
        ui_print "  Magisk cannot replace those. microG would not load and every"
        ui_print "  Google dependent app on the device would crash after reboot."
        ui_print " "
        ui_print "  Do this first, then flash again:"
        ui_print "    1. Turn off wifi and mobile data"
        ui_print "    2. Settings, Apps, then show system apps"
        ui_print "    3. For Google Play Services, Google Play Store and Google"
        ui_print "       Services Framework, uninstall updates then clear storage"
        ui_print "    4. Reboot, then flash this module"
        ui_print " "
        abort "! Nothing was changed. Your device is untouched."
    fi
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
    ui_print "  microG needs signature spoofing from the ROM. If microG Self-Check"
    ui_print "  shows it red after reboot, this ROM does not provide it. On stock"
    ui_print "  ROMs you need LSPosed with FakeGApps to supply it instead."
fi

set_perm_recursive "$MODPATH/system" 0 0 0755 0644
