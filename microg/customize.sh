#!/system/bin/sh
##############################################################################
#  DresOS microG: customize.sh
#
#  Install time entry point. Runs once inside Magisk at flash time.
#
#  Design contract (this is the rule book; deviations cause boot loops):
#    1. customize.sh does FILE WORK ONLY. No pm uninstall, no
#       cmd package install-existing, no pm grant, no pm disable. Every
#       PackageManager mutation lives in service.sh, where it runs after
#       sys.boot_completed and a settling delay. Running pm uninstall
#       at flash time against an existing ROM provided microG strips
#       the user's working install before our replacement is registered.
#    2. We do NOT make per package install decisions based on cert
#       hashes computed from the on disk APK at flash time. The
#       META-INF RSA hash legitimately varies between build environments
#       for APKs signed by the same key. Cert identity is verified post
#       boot via `cmd package dump`, which gives us PMS's own SHA 256
#       of the X.509 DER cert. Until then we stage every managed
#       component unconditionally.
#    3. We NEVER lay a directory level .replace marker on a priv-app
#       dir. On Android 14 plus that hides the ART OAT cache under
#       <dir>/oat/, ART falls back to interpretation, and the device
#       misses boot complete. Debloat is runtime pm disable user from
#       service.sh.
#    4. The APK and its matching privapp-permissions XML MUST land in
#       the same partition. Android 11 plus enforces this. We compute
#       the partition once from the API level (product on API 28 plus,
#       root system on API 26 and 27) and write both the APKs and the
#       XMLs under that single root.
##############################################################################

SKIPUNZIP=0

. "$MODPATH/common/constants.sh"
. "$MODPATH/common/functions.sh"

##############################################################################
#  Banner.
##############################################################################
if [ -f "$MODPATH/common/ascii_banner.txt" ]; then
    while IFS= read -r L; do ui_print "$L"; done < "$MODPATH/common/ascii_banner.txt"
fi
ui_print " "
ui_print "==============================================="
ui_print "  DresOS microG v2.0.0"
ui_print "  microG 0.3.7.250932 plus Companion plus"
ui_print "  GsfProxy plus DroidGuard plus Aurora Store"
ui_print "  plus Aurora Services"
ui_print " "
ui_print "  PMS work runs after boot complete."
ui_print "  Debloat is runtime pm disable user."
ui_print "  No directory level replace markers."
ui_print " "
ui_print "  dresoperatingsystems.github.io"
ui_print "==============================================="
ui_print " "

load_config

##############################################################################
#  Stage 1: Magisk version gate. v24.0 minimum because Zygisk landed in
#  the v24 series and we ship a Zygisk signature spoofer. KernelSU and
#  APatch expose the same MAGISK_VER_CODE contract provided the user
#  has ZygiskNext or ReZygisk installed.
##############################################################################
if [ -z "$MAGISK_VER_CODE" ] || [ "$MAGISK_VER_CODE" -lt 24000 ]; then
    ui_print "! Magisk 24.0 or newer is required (Zygisk capable)."
    ui_print "! On KernelSU or APatch install ZygiskNext or ReZygisk first."
    ui_print "! Detected Magisk version code: $MAGISK_VER_CODE"
    abort "! Aborting install."
fi
ui_print "  Magisk version code: $MAGISK_VER_CODE"

##############################################################################
#  Stage 2: Android API gate.
##############################################################################
API_LEVEL=$(GP ro.build.version.sdk)
ANDROID_REL=$(GP ro.build.version.release)
ui_print "  Android version:  $ANDROID_REL (API $API_LEVEL)"

if [ "$API_LEVEL" -lt 26 ]; then
    ui_print "! Android 8.0 (API 26) or newer is required."
    ui_print "! cmd package install-existing does not exist before API 26."
    abort "! Aborting install."
fi
TESTED_MAX_API=36
if [ "$API_LEVEL" -gt "$TESTED_MAX_API" ]; then
    ui_print "! Untested on API $API_LEVEL (tested up to API $TESTED_MAX_API)."
    ui_print "! Proceeding. Report issues at the support URL in module.prop."
fi

##############################################################################
#  Stage 3: ABI selection.
##############################################################################
ABI=$(GP ro.product.cpu.abi)
ui_print "  Device ABI:       $ABI"
case "$ABI" in
    arm64-v8a)           APK_LIBDIR="lib/arm64-v8a"   ; OUT_LIBDIR="arm64"   ; ZYG_SO="arm64-v8a.so"   ;;
    armeabi-v7a|armeabi) APK_LIBDIR="lib/armeabi-v7a" ; OUT_LIBDIR="arm"     ; ZYG_SO="armeabi-v7a.so" ;;
    x86_64)              APK_LIBDIR="lib/x86_64"      ; OUT_LIBDIR="x86_64"  ; ZYG_SO="x86_64.so"      ;;
    x86)                 APK_LIBDIR="lib/x86"         ; OUT_LIBDIR="x86"     ; ZYG_SO="x86.so"         ;;
    *)
        ui_print "! Unsupported ABI: $ABI"
        abort "! Aborting install."
        ;;
esac

##############################################################################
#  Stage 4: GrapheneOS hard abort.
##############################################################################
if is_grapheneos; then
    ui_print " "
    ui_print "************************************************"
    ui_print "*  GrapheneOS detected."
    ui_print "*  GrapheneOS does NOT implement signature"
    ui_print "*  spoofing and recommends Sandboxed Google"
    ui_print "*  Play instead. This module will not work on"
    ui_print "*  GrapheneOS and could weaken security."
    ui_print "*  Refusing to install."
    ui_print "************************************************"
    abort "! Aborting on GrapheneOS."
fi

##############################################################################
#  Stage 5: ROM probe, native sigspoof probe, native microG probe.
#  These are diagnostic only at install time. The real cert based
#  decision happens in service.sh post boot.
##############################################################################
ROM=$(detect_rom)
ui_print " "
ui_print "  Detected ROM:     $ROM"

NATIVE_SPOOF=0
if rom_provides_sigspoof; then
    NATIVE_SPOOF=1
    ui_print "  Native sigspoof:  yes (ROM patches PMS)"
else
    ui_print "  Native sigspoof:  no (Zygisk fallback will install)"
fi

AOSMIUM_PRESENT=0
if is_aosmium_active; then
    AOSMIUM_PRESENT=1
    ui_print "  AOSmium WebView:  present (coexisting)"
else
    ui_print "  AOSmium WebView:  absent"
fi

ROM_MICROG_HINT=0
if rom_ships_working_microg com.google.android.gms; then
    ROM_MICROG_HINT=1
    ui_print "  ROM microG hint:  present (will verify cert post boot)"
fi

ui_print " "
ui_print "  Debloat:          $DRESOS_DEBLOAT_ENABLE  (runtime pm disable)"
ui_print "  Harden:           $DRESOS_HARDEN_ENABLE"
ui_print "  Wallpaper:        $DRESOS_WALLPAPER_ENABLE"
ui_print "  Safe install:     $DRESOS_SAFE_INSTALL"

##############################################################################
#  Stage 6: Pick the priv-app partition for this API level. The APKs and
#  their privapp-permissions XML MUST land in the SAME partition. This
#  is the Android 11 plus same partition rule and PMS silently ignores
#  cross partition matches.
##############################################################################
PRIV_PARTITION=$(pick_priv_app_partition "$API_LEVEL")
PRIV_APP_ROOT="$PRIV_PARTITION/priv-app"
PRIV_ETC_PERM="$PRIV_PARTITION/etc/permissions"
PRIV_ETC_SYSCFG="$PRIV_PARTITION/etc/sysconfig"

ui_print "  Staging root:     /$PRIV_PARTITION"
ui_print " "

mkdir -p "$MODPATH/$PRIV_APP_ROOT"
mkdir -p "$MODPATH/$PRIV_ETC_PERM"
mkdir -p "$MODPATH/$PRIV_ETC_SYSCFG"

##############################################################################
#  Stage 7: Stage each managed component's APK at the partition's
#  priv-app/<DIRNAME>/<DIRNAME>.apk. Unconditional. service.sh decides
#  post boot whether the ROM also provides the package and whether our
#  copy ends up the active one. The MG suffix on each dirname avoids
#  collisions with stock priv-app dirs of the same name on OEM ROMs.
##############################################################################
ui_print "  Staging managed APKs"

SAFE_MODE_PKGS_SKIP="com.google.android.gms com.android.vending com.google.android.gsf"

stage_one() {
    pkg="$1"; apkname="$2"; dirname="$3"
    if [ "$DRESOS_SAFE_INSTALL" = "1" ]; then
        case " $SAFE_MODE_PKGS_SKIP " in
            *" $pkg "*)
                ui_print "    - $pkg  (skipped: safe_install mode)"
                return
                ;;
        esac
    fi
    src="$MODPATH/apk/$apkname"
    if [ ! -f "$src" ]; then
        ui_print "    ! bundled $apkname missing, refusing to stage $pkg"
        return
    fi
    dest_dir="$MODPATH/$PRIV_APP_ROOT/$dirname"
    mkdir -p "$dest_dir"
    cp -f "$src" "$dest_dir/$dirname.apk"
    ui_print "    + $pkg -> /$PRIV_APP_ROOT/$dirname/"
}

echo "$DRESOS_STAGING_TABLE" | while IFS='|' read -r pkg apkname dirname cert; do
    [ -z "$pkg" ] && continue
    stage_one "$pkg" "$apkname" "$dirname"
done

##############################################################################
#  Stage 7b: GmsCore native library extraction for the device ABI only.
#  Magisk magic mount does not run the PackageManager style native
#  library extraction, so the in process native modules inside GmsCore
#  (conscrypt, mapsv2, breakpad) would not load without this.
##############################################################################
if [ "$DRESOS_SAFE_INSTALL" != "1" ]; then
    GMS_DEST="$MODPATH/$PRIV_APP_ROOT/GmsCoreMG"
    if [ -d "$GMS_DEST" ] && [ -f "$MODPATH/apk/GmsCore.apk" ]; then
        ui_print "    extracting GmsCore native libs for $ABI"
        mkdir -p "$GMS_DEST/lib/$OUT_LIBDIR"
        unzip -j -o "$MODPATH/apk/GmsCore.apk" "$APK_LIBDIR/*" \
              -d "$GMS_DEST/lib/$OUT_LIBDIR" >/dev/null 2>&1 || true
    fi
fi

##############################################################################
#  Stage 8: privapp-permissions XML. AOSP defined permissions only.
#
#  FAKE_PACKAGE_SIGNATURE is microG's own permission, declared in the
#  GmsCore manifest. It is NOT an AOSP permission. Some Android 15 plus
#  builds will refuse to boot if an unknown permission appears in a
#  privapp-permissions whitelist. We grant it at runtime via pm grant
#  from service.sh and action.sh instead.
##############################################################################
PERM_XML="$MODPATH/$PRIV_ETC_PERM/privapp-permissions-dresos-microg.xml"
ui_print " "
ui_print "  Writing privapp permissions XML at /$PRIV_ETC_PERM/"

cat > "$PERM_XML" <<'XMLHDR'
<?xml version="1.0" encoding="utf-8"?>
<!--
  DresOS microG
  Privileged permission whitelist.
  Same partition as the APKs. Android 11 plus enforces this.
  Only AOSP framework defined permissions appear here. microG's own
  FAKE_PACKAGE_SIGNATURE is granted at runtime via pm grant.
-->
<permissions>
XMLHDR

if [ "$DRESOS_SAFE_INSTALL" != "1" ]; then
    cat >> "$PERM_XML" <<'X'
    <privapp-permissions package="com.google.android.gms">
        <permission name="android.permission.INSTALL_LOCATION_PROVIDER"/>
        <permission name="android.permission.UPDATE_APP_OPS_STATS"/>
        <permission name="android.permission.UPDATE_DEVICE_STATS"/>
        <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
        <permission name="android.permission.GET_ACCOUNTS_PRIVILEGED"/>
        <permission name="android.permission.LOCAL_MAC_ADDRESS"/>
        <permission name="android.permission.PACKAGE_USAGE_STATS"/>
        <permission name="android.permission.READ_PRIVILEGED_PHONE_STATE"/>
        <permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND"/>
        <permission name="android.permission.MANAGE_USB"/>
        <permission name="android.permission.REAL_GET_TASKS"/>
        <permission name="android.permission.LOCATION_HARDWARE"/>
        <permission name="android.permission.BLUETOOTH_PRIVILEGED"/>
    </privapp-permissions>

    <privapp-permissions package="com.android.vending">
        <permission name="android.permission.INSTALL_PACKAGES"/>
        <permission name="android.permission.UPDATE_APP_OPS_STATS"/>
        <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
        <permission name="android.permission.PACKAGE_USAGE_STATS"/>
    </privapp-permissions>
X
fi

cat >> "$PERM_XML" <<'X'
    <privapp-permissions package="com.aurora.store">
        <permission name="android.permission.PACKAGE_USAGE_STATS"/>
        <permission name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    </privapp-permissions>

    <privapp-permissions package="com.aurora.services">
        <permission name="android.permission.INSTALL_PACKAGES"/>
        <permission name="android.permission.DELETE_PACKAGES"/>
    </privapp-permissions>
X

echo '</permissions>' >> "$PERM_XML"
ui_print "    privapp permissions XML written"

##############################################################################
#  Stage 9: hiddenapi sysconfig XML.
##############################################################################
HIDDENAPI_XML="$MODPATH/$PRIV_ETC_SYSCFG/dresos-microg-hiddenapi.xml"
cat > "$HIDDENAPI_XML" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<!--
  DresOS microG
  Hidden API whitelist for microG and Aurora Store.
-->
<config>
    <hidden-api-whitelisted-app package="com.google.android.gms"/>
    <hidden-api-whitelisted-app package="com.android.vending"/>
    <hidden-api-whitelisted-app package="com.aurora.store"/>
    <hidden-api-whitelisted-app package="com.aurora.services"/>
</config>
XML
ui_print "  Wrote hidden API whitelist at /$PRIV_ETC_SYSCFG/"

##############################################################################
#  Stage 10: Wallpaper staging.
##############################################################################
if [ "$DRESOS_WALLPAPER_ENABLE" = "1" ] \
   && [ -f "$MODPATH/wallpapers/dresos_default.jpg" ]; then
    ui_print "  DresOS default wallpaper staged for first boot"
    touch "$MODPATH/.needs_first_boot_wallpaper"
fi

##############################################################################
#  Stage 11: Zygisk signature spoofing payload.
##############################################################################
if [ "$NATIVE_SPOOF" = "1" ]; then
    ui_print " "
    ui_print "  Removing Zygisk sigspoof (ROM handles it natively)"
    rm -rf "$MODPATH/zygisk"
    rm -f  "$MODPATH/google.cer"
else
    if [ ! -f "$MODPATH/zygisk/$ZYG_SO" ]; then
        if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "armeabi" ] || [ "$ABI" = "x86" ]; then
            ui_print " "
            ui_print "  NOTICE: prebuilt $ZYG_SO not in this build."
            ui_print "    Zygisk sigspoof inactive on this ABI."
            ui_print "    Fallback: install LSPosed (JingMatrix fork) plus"
            ui_print "    FakeGApps to spoof signatures."
            touch "$MODPATH/zygisk_inactive_for_abi"
            rm -rf "$MODPATH/zygisk"
            rm -f  "$MODPATH/google.cer"
        else
            ui_print "! Zygisk object $ZYG_SO missing from this build."
            abort "! Aborting install."
        fi
    else
        ui_print " "
        ui_print "  Staging Zygisk sigspoof: zygisk/$ZYG_SO"
        KEEP_SO="$MODPATH/zygisk/$ZYG_SO"
        TMP_SO="$MODPATH/$ZYG_SO.keep"
        cp -f "$KEEP_SO" "$TMP_SO"
        rm -rf "$MODPATH/zygisk"
        mkdir -p "$MODPATH/zygisk"
        mv -f "$TMP_SO" "$MODPATH/zygisk/$ZYG_SO"
        if [ ! -f "$MODPATH/google.cer" ]; then
            ui_print "! Google certificate missing from the module zip."
            abort "! Aborting install."
        fi
    fi
fi

##############################################################################
#  Stage 12: Permissions and SELinux contexts.
##############################################################################
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
for f in $(find "$MODPATH/system" -name '*.apk' 2>/dev/null); do
    set_perm "$f" 0 0 0644
done
for f in $(find "$MODPATH/system" -name '*.xml' 2>/dev/null); do
    set_perm "$f" 0 0 0644
done

if [ -f "$MODPATH/google.cer" ]; then
    set_perm "$MODPATH/google.cer" 0 0 0600
fi
if [ -d "$MODPATH/zygisk" ]; then
    set_perm_recursive "$MODPATH/zygisk" 0 0 0755 0644
fi
if [ -f "$MODPATH/wallpapers/dresos_default.jpg" ]; then
    set_perm "$MODPATH/wallpapers/dresos_default.jpg" 0 0 0644
fi

##############################################################################
#  Stage 13: Persist install state under /data/adb/dresosmicrog/.
##############################################################################
mkdir -p "$DRESOS_STATE_DIR"
echo "$ROM"                    > "$DRESOS_STATE_DIR/rom"
echo "$NATIVE_SPOOF"           > "$DRESOS_STATE_DIR/native_spoof"
echo "$AOSMIUM_PRESENT"        > "$DRESOS_STATE_DIR/aosmium"
echo "$ROM_MICROG_HINT"        > "$DRESOS_STATE_DIR/rom_microg_hint"
echo "$ABI"                    > "$DRESOS_STATE_DIR/abi"
echo "$API_LEVEL"              > "$DRESOS_STATE_DIR/api"
echo "$PRIV_PARTITION"         > "$DRESOS_STATE_DIR/priv_partition"
echo "$DRESOS_DEBLOAT_ENABLE"  > "$DRESOS_STATE_DIR/debloat_enabled"
echo "$DRESOS_HARDEN_ENABLE"   > "$DRESOS_STATE_DIR/harden_enabled"
echo "$DRESOS_SAFE_INSTALL"    > "$DRESOS_STATE_DIR/safe_install"
date '+%Y-%m-%d %H:%M:%S'     > "$DRESOS_STATE_DIR/installed_at"
date '+%s'                    > "$DRESOS_STATE_DIR/installed_at_epoch"

bootloop_clear >/dev/null
rm -f "$DRESOS_STATE_DIR/last_boot_ok_epoch"    2>/dev/null
rm -f "$DRESOS_STATE_DIR/disable_zygisk"        2>/dev/null
rm -f "$DRESOS_STATE_DIR/disable_priv_app"      2>/dev/null
rm -f "$DRESOS_STATE_DIR/disable_debloat"       2>/dev/null
rm -f "$DRESOS_STATE_DIR/.aurora_data_cleaned"  2>/dev/null
rm -f "$DRESOS_STATE_DIR/.wallpaper_applied"    2>/dev/null
rm -f "$DRESOS_STATE_DIR"/stage.*               2>/dev/null

mkdir -p "$MODPATH/$DRESOS_LOG_DIR_REL"
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] install OK"
    echo "  rom=$ROM api=$API_LEVEL abi=$ABI"
    echo "  native_spoof=$NATIVE_SPOOF aosmium=$AOSMIUM_PRESENT"
    echo "  rom_microg_hint=$ROM_MICROG_HINT"
    echo "  priv_partition=$PRIV_PARTITION"
    echo "  debloat=$DRESOS_DEBLOAT_ENABLE harden=$DRESOS_HARDEN_ENABLE"
    echo "  safe_install=$DRESOS_SAFE_INSTALL"
    echo "  staged components:"
    find "$MODPATH/$PRIV_APP_ROOT" -name '*.apk' 2>/dev/null | while read -r f; do
        echo "    $f"
    done
} > "$MODPATH/$DRESOS_LOG_DIR_REL/install.log"

##############################################################################
#  Stage 14: Cleanup.
##############################################################################
rm -rf "$MODPATH/apk"
rm -f  "$MODPATH/boot_pending"   2>/dev/null
rm -f  "$MODPATH/inert"          2>/dev/null
rm -f  "$MODPATH/disable"        2>/dev/null
rm -f  "$MODPATH/remove"         2>/dev/null

##############################################################################
#  Stage 15: Confirmation banner.
##############################################################################
ui_print " "
ui_print "==============================================="
ui_print "  Install complete."
ui_print " "
ui_print "  Summary at /data/adb/modules/$DRESOS_MODID/logs/install.log"
ui_print "  Reboot to activate the staged priv-apps."
ui_print " "
ui_print "  After boot:"
ui_print "    1. Open microG Settings, Self Check."
ui_print "       SafetyNet stays red by design."
ui_print "    2. Open Aurora Store, Settings, Installer."
ui_print "       Set to 'Aurora Services' for silent installs."
ui_print "       Use ANONYMOUS login (no Google account)."
ui_print " "
ui_print "  Bootloop sentinel armed (heartbeat driven, per component)."
ui_print "  Triple Volume Down at boot to engage Magisk safe mode."
ui_print " "
ui_print "  Diagnostics: Magisk app, Modules, Action."
ui_print "==============================================="
ui_print " "
