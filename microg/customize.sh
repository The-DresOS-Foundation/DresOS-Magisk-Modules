#!/system/bin/sh
##############################################################################
#  DresOS microG  v3.1.1  customize.sh
#
#  Mostly a file overlay: customize.sh validates the environment, picks the
#  partition, masks any real Google Play Services so microG can take its
#  place, sets permissions, and reports exactly what will happen.
#
#  What it does NOT do:
#    - run any Zygisk or Xposed payload
#    - mutate PackageManager at boot
#    - write to, disable, or delete any OTHER Magisk module
#  A small bootloop watchdog (post-fs-data.sh + service.sh) is included; it
#  only ever disables THIS module if a boot never completes, so a bad ROM
#  recovers on its own instead of looping.
#
#  Signature spoofing is provided by the ROM. The bundled GmsCore and
#  Companion are the OFFICIALLY signed microG builds (key 9bd06727...), so a
#  ROM with microG signature-spoofing support (LineageOS 2024-02-26+, e/OS,
#  CalyxOS, iodeOS, DivestOS, and others) spoofs them automatically. On a ROM
#  with no spoofing, microG still installs but signature-dependent apps are
#  limited; the installer tells you so plainly.
##############################################################################

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
echo " "
echo "==============================================="
echo "  DresOS microG  v3.1.1"
echo "  Officially signed microG for ROMs with"
echo "  microG signature spoofing (system-provided)."
echo "  Systemless overlay with bootloop watchdog"
echo "==============================================="
echo " "

##  1. Must run from the Magisk/KernelSU/APatch app, not recovery.
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

##  4. GrapheneOS refuses signature spoofing entirely; never install there.
if [ -f /system/etc/grapheneos-release ] || GP ro.build.fingerprint | grep -qi grapheneos; then
    abort "! GrapheneOS does not support signature spoofing. Not installing."
fi

##  5. Detect any existing com.google.android.gms and decide what it is.
##     microG (ours, or a prior install) REQUESTS android.permission.FAKE_PACKAGE_SIGNATURE.
##     Real Google Play Services does NOT. That is how we tell them apart.
REAL_GMS=0
GMS_PATH=$(pm path com.google.android.gms 2>/dev/null | head -1 | sed 's/^package://')
if [ -n "$GMS_PATH" ]; then
    if pm dump com.google.android.gms 2>/dev/null | grep -qi 'fake_package_signature'; then
        echo "  Existing GmsCore     : microG (will be replaced by the bundled build)"
    else
        REAL_GMS=1
        echo "  Existing GmsCore     : real Google Play Services (will be masked)"
    fi
fi

##     Systemless-debloat helper. Mirrors the stock app's directory inside this
##     module and drops a Magisk ".replace" marker, which empties that directory
##     at mount time. It is fully reversible: disabling or removing this module
##     restores the stock app. We only ever mask the three Google packages microG
##     replaces, and only when they are real Google builds on a system partition.
mask_stock_pkg() {
    pkg="$1"
    p=$(pm path "$pkg" 2>/dev/null | head -1 | sed 's/^package://')
    [ -n "$p" ] || return 0
    # Skip if this package is microG-keyed (requests FAKE_PACKAGE_SIGNATURE).
    pm dump "$pkg" 2>/dev/null | grep -qi 'fake_package_signature' && return 0
    d=$(dirname "$p")
    case "$d" in
        /system/product/*)    t="$MODPATH/system/product${d#/system/product}" ;;
        /product/*)           t="$MODPATH/system/product${d#/product}" ;;
        /system/system_ext/*) t="$MODPATH/system/system_ext${d#/system/system_ext}" ;;
        /system_ext/*)        t="$MODPATH/system/system_ext${d#/system_ext}" ;;
        /system/*)            t="$MODPATH/system${d#/system}" ;;
        *) echo "  ! $pkg lives at $d (data/unknown); cannot mask systemlessly."; return 0 ;;
    esac
    mkdir -p "$t" && : > "$t/.replace"
    echo "  Masked stock $pkg"
}

if [ "$REAL_GMS" -eq 1 ]; then
    echo " "
    echo "  Real Google Play Services is present. This module will mask it"
    echo "  (and the Google Play Store and Services Framework) so microG can"
    echo "  take over those package names. This is systemless and reversible:"
    echo "  remove this module to get the stock Google apps back."
    echo " "
    mask_stock_pkg com.google.android.gms
    mask_stock_pkg com.android.vending
    mask_stock_pkg com.google.android.gsf
    echo " "
fi

##  6. Partition selection. Modern devices (API 28+) read priv-app permission
##     allowlists from /product. Old devices without product fall back to
##     /system. The allowlist XML always travels on the SAME partition as the
##     APKs. Any masks we just created under system/product are remapped too.
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
    # Move any .replace masks created under system/product to the /system tree.
    if [ -d "$PRODUCT" ]; then
        ( cd "$PRODUCT" && find . -name .replace -type f 2>/dev/null ) | while IFS= read -r r; do
            sub=${r#./}
            mkdir -p "$MODPATH/system/$(dirname "$sub")"
            : > "$MODPATH/system/$sub"
        done
    fi
    rm -rf "$MODPATH/system/product"
else
    echo "  Partition           : /product (via system/product)"
fi
echo " "

##  7. Report the signature situation and, if needed, how to add spoofing.
SPOOF="unknown"
if GP ro.calyxos.version | grep -q . ; then SPOOF="yes (CalyxOS)"; fi
if GP ro.iode.version    | grep -q . ; then SPOOF="yes (iodeOS)"; fi
if GP ro.e.version       | grep -q . ; then SPOOF="yes (e/OS)"; fi
if GP ro.divest.version  | grep -q . ; then SPOOF="yes (DivestOS)"; fi
if [ "$SPOOF" = "unknown" ] && GP ro.lineage.version | grep -q . ; then
    SPOOF="likely (LineageOS) if this build is 2024-02-26 or newer AND a userdebug build"
fi
echo "  ROM signature spoof : $SPOOF"
if echo "$SPOOF" | grep -qi unknown; then
    echo " "
    echo "  This ROM is not on the built-in signature-spoofing list (most stock"
    echo "  OEM firmware and standard LineageOS are not). microG needs spoofing"
    echo "  for signature-checking apps to work. To add it:"
    echo " "
    if [ "${API:-0}" -ge 36 ]; then
        echo "   Your Android version is 16 (API $API). The clean spoofing tools do"
        echo "   not support 16 yet: FakeGApps caps at Android 15 and the"
        echo "   services.jar patchers fail on 16. For full microG on 16 today, use"
        echo "   a ROM with built-in microG spoofing (LineageOS for microG, e/OS,"
        echo "   CalyxOS, iodeOS, DivestOS). On Android 15 or below, install LSPosed"
        echo "   (JingMatrix fork) + FakeGApps to enable spoofing."
    else
        echo "   Android 15 and below:"
        echo "    1. Enable Zygisk in Magisk settings."
        echo "    2. Install LSPosed (JingMatrix fork) as a Magisk module, reboot."
        echo "    3. Install the FakeGApps APK, open LSPosed, enable FakeGApps,"
        echo "       then reboot."
        echo "   On Android 16, FakeGApps is not ready yet; a ROM with built-in"
        echo "   microG spoofing is needed there for now."
    fi
    echo " "
    echo "  This module ships no Xposed/Zygisk spoofing layer of its own (an"
    echo "  earlier version did and it bootlooped devices). After reboot, microG"
    echo "  Settings > Self-Check: 'System spoofs signature' must be green. If it"
    echo "  is red, spoofing is not active here yet."
fi
echo " "

##  8. Coexistence note (informational only; we never touch other modules).
for d in /data/adb/modules/*/; do
    [ -f "$d/module.prop" ] || continue
    id=$(grep '^id=' "$d/module.prop" 2>/dev/null | cut -d= -f2)
    case "$id" in
        *[Aa][Oo][Ss]mium*|*aosmium*|dresoswv|dresoswebview)
            [ -f "$d/disable" ] || echo "  Coexisting module   : $id (left untouched)"
            ;;
    esac
done

##  9. Permissions on our own tree only.
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
