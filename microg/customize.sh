#!/system/bin/sh
##############################################################################
#  DresOS microG  v3.0.0  customize.sh
#
#  This module is a PURE FILE OVERLAY. customize.sh only validates the
#  environment, picks the right partition, sets permissions, and reports
#  what will happen. It does NOT:
#    - run any Zygisk or Xposed payload
#    - mutate PackageManager at boot
#    - write to, disable, or delete any OTHER Magisk module
#    - touch Zygisk global state
#  That is the whole reason it cannot bootloop the device or knock out a
#  sibling module such as AOSmium WebView.
#
#  Signature spoofing is provided by the ROM, not by this module. The
#  bundled GmsCore and Companion are the OFFICIALLY signed microG builds
#  (key 9bd06727...), so any ROM that supports microG signature spoofing
#  (LineageOS 2024-02-26+, e/OS, CalyxOS, iodeOS, DivestOS, and others)
#  will spoof them automatically once they sit in priv-app with the
#  allowlist this module ships.
##############################################################################

SKIPUNZIP=0
PRODUCT="$MODPATH/system/product"

ui_print() { echo "$1"; }
# (Magisk provides ui_print; this stub is only a safety net for odd shells.)

print_banner() {
    if [ -f "$MODPATH/common/ascii_banner.txt" ]; then
        while IFS= read -r L; do echo "$L"; done < "$MODPATH/common/ascii_banner.txt"
    fi
}

GP() { getprop "$1" 2>/dev/null; }

print_banner
echo " "
echo "==============================================="
echo "  DresOS microG  v3.0.0"
echo "  Officially signed microG 0.3.15 suite"
echo "  Pure systemless overlay, bootloop-safe"
echo "==============================================="
echo " "

##  1. Recovery installs are not supported (PMS must be live for nothing
##     here, but recovery cannot evaluate priv-app permissions correctly).
if [ "$BOOTMODE" != "true" ]; then
    abort "! Install from the Magisk app, not recovery/TWRP."
fi

##  2. Magisk version gate.
if [ -z "$MAGISK_VER_CODE" ] || [ "$MAGISK_VER_CODE" -lt 24000 ]; then
    abort "! Magisk 24.0+ required (found $MAGISK_VER_CODE)."
fi
echo "  Magisk version code : $MAGISK_VER_CODE"

##  3. API gate.
API=$(GP ro.build.version.sdk)
echo "  Android API level   : $API"
if [ -z "$API" ] || [ "$API" -lt 26 ]; then
    abort "! Android 8.0 (API 26) or newer required."
fi

ABI=$(GP ro.product.cpu.abi)
echo "  Device ABI          : $ABI"
echo "  Device              : $(GP ro.product.manufacturer) $(GP ro.product.model)"
echo " "

##  4. GrapheneOS refuses signature spoofing entirely.
if [ -f /system/etc/grapheneos-release ] || GP ro.build.fingerprint | grep -qi grapheneos; then
    abort "! GrapheneOS does not support signature spoofing. Not installing."
fi

##  5. Refuse if real Google Play Services is present (would collide with
##     the bundled microG that shares the package name).
GMS_PATH=$(pm path com.google.android.gms 2>/dev/null | head -1 | sed 's/^package://')
if [ -n "$GMS_PATH" ]; then
    case "$GMS_PATH" in
        *PrebuiltGmsCore*|*/GmsCore*/base.apk|*google*)
            # Could be a prior microG from this module; check signer.
            SIG=$(pm dump com.google.android.gms 2>/dev/null | grep -iE 'fake_package_signature' )
            if [ -z "$SIG" ]; then
                echo "! com.google.android.gms is already installed and does not look"
                echo "! like microG (no FAKE_PACKAGE_SIGNATURE request)."
                echo "! Remove Google Play Services / GApps first, then reflash."
                abort "! Aborting to avoid a package collision."
            fi
            ;;
    esac
fi

##  6. Partition selection. Modern devices (API 28+) read priv-app
##     permission allowlists from /product. Very old devices without a
##     product partition fall back to /system. The allowlist XML always
##     travels on the SAME partition as the APKs.
if [ "$API" -lt 28 ] || { [ ! -d /product ] && [ ! -L /system/product ]; }; then
    echo "  Partition           : /system (legacy fallback)"
    mkdir -p "$MODPATH/system/priv-app" "$MODPATH/system/app" \
             "$MODPATH/system/etc/permissions" "$MODPATH/system/etc/sysconfig" \
             "$MODPATH/system/etc/default-permissions"
    cp -a "$PRODUCT/priv-app/." "$MODPATH/system/priv-app/" 2>/dev/null
    cp -a "$PRODUCT/app/." "$MODPATH/system/app/" 2>/dev/null
    cp -a "$PRODUCT/etc/permissions/." "$MODPATH/system/etc/permissions/" 2>/dev/null
    cp -a "$PRODUCT/etc/sysconfig/." "$MODPATH/system/etc/sysconfig/" 2>/dev/null
    cp -a "$PRODUCT/etc/default-permissions/." "$MODPATH/system/etc/default-permissions/" 2>/dev/null
    rm -rf "$MODPATH/system/product"
else
    echo "  Partition           : /product (via system/product)"
fi
echo " "

##  7. Report whether THIS ROM will spoof the microG signature.
SPOOF="unknown"
if GP ro.calyxos.version | grep -q . ; then SPOOF="yes (CalyxOS)"; fi
if GP ro.iode.version    | grep -q . ; then SPOOF="yes (iodeOS)"; fi
if GP ro.e.version       | grep -q . ; then SPOOF="yes (e/OS)"; fi
if GP ro.divest.version  | grep -q . ; then SPOOF="yes (DivestOS)"; fi
if [ "$SPOOF" = "unknown" ] && GP ro.lineage.version | grep -q . ; then
    # LineageOS gained the microG-only sigspoof patch on 2024-02-26.
    SPOOF="yes if this LineageOS build is from 2024-02-26 or later"
fi
echo "  ROM signature spoof : $SPOOF"
if echo "$SPOOF" | grep -qi unknown; then
    echo " "
    echo "  NOTE: This ROM is not on the known signature-spoofing list."
    echo "  microG will still install and run, but apps that verify the"
    echo "  Google signature will only work if your ROM provides microG"
    echo "  signature spoofing. This module deliberately does NOT bundle an"
    echo "  Xposed spoofing layer, because that is what was bootlooping the"
    echo "  device. If your ROM lacks native support, use a ROM that has it."
fi
echo " "

##  8. Coexistence note (informational only; we never touch other modules).
for d in /data/adb/modules/*/; do
    [ -f "$d/module.prop" ] || continue
    id=$(grep '^id=' "$d/module.prop" 2>/dev/null | cut -d= -f2)
    case "$id" in
        *[Aa][Oo][Ss]mium*|*aosmium*|dresoswv)
            [ -f "$d/disable" ] || echo "  Coexisting module   : $id (left untouched)"
            ;;
    esac
done

##  9. Permissions. Only our own tree.
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
echo " "
echo "==============================================="
echo "  Install complete."
echo " "
echo "  Reboot. First boot may take a few minutes while"
echo "  PackageManager scans GmsCore. Do not force reboot."
echo " "
echo "  After boot, open microG Settings, Self-Check."
echo "  On a spoofing-capable ROM all core lines go green."
echo "  In Aurora Store, set the installer to Aurora"
echo "  Services and log in anonymously (no Google account)."
echo "==============================================="
echo " "
