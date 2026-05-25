#!/system/bin/sh
##############################################################################
#  DresOS microG: action.sh
#
#  Runs when the user taps the Action button on this module entry in the
#  Magisk app. Three jobs:
#    1. Print the full diagnostic status dashboard to the toast output.
#    2. Regrant runtime permissions to microG and Aurora.
#    3. Restart the microG components so they pick up any changes.
##############################################################################

MODDIR=${0%/*}
. "$MODDIR/common/constants.sh"
. "$MODDIR/common/functions.sh"

GMS_PKG="com.google.android.gms"
CMP_PKG="com.android.vending"
GSF_PKG="com.google.android.gsf"
DG_PKG="org.microg.gms.droidguard"
AS_PKG="com.aurora.store"
APS_PKG="com.aurora.services"

load_config

echo "DresOS microG status"
echo "===================="
echo ""
echo "Module path: $MODDIR"
echo "State dir:   $DRESOS_STATE_DIR"
echo ""

if [ -f "$DRESOS_STATE_DIR/installed_at" ]; then
    echo "Installed at:       $(cat "$DRESOS_STATE_DIR/installed_at")"
fi
if [ -f "$DRESOS_STATE_DIR/rom" ]; then
    echo "ROM:                $(cat "$DRESOS_STATE_DIR/rom")"
fi
if [ -f "$DRESOS_STATE_DIR/api" ]; then
    echo "API level:          $(cat "$DRESOS_STATE_DIR/api")"
fi
if [ -f "$DRESOS_STATE_DIR/abi" ]; then
    echo "ABI:                $(cat "$DRESOS_STATE_DIR/abi")"
fi
if [ -f "$DRESOS_STATE_DIR/priv_partition" ]; then
    echo "Priv partition:     /$(cat "$DRESOS_STATE_DIR/priv_partition")"
fi
if [ -f "$DRESOS_STATE_DIR/native_spoof" ]; then
    if [ "$(cat "$DRESOS_STATE_DIR/native_spoof")" = "1" ]; then
        echo "Sigspoof:           ROM native"
    elif [ -d "$MODDIR/zygisk" ]; then
        echo "Sigspoof:           Zygisk hook (active)"
    elif [ -f "$MODDIR/zygisk_inactive_for_abi" ]; then
        echo "Sigspoof:           inactive on this ABI (install LSPosed + FakeGApps)"
    else
        echo "Sigspoof:           inactive (Zygisk component disabled by sentinel?)"
    fi
fi
echo ""
echo "Config:"
echo "  debloat        = $DRESOS_DEBLOAT_ENABLE"
echo "  harden         = $DRESOS_HARDEN_ENABLE"
echo "  wallpaper      = $DRESOS_WALLPAPER_ENABLE"
echo "  aurora_backend = $DRESOS_AURORA_BACKEND"
echo "  safe_install   = $DRESOS_SAFE_INSTALL"
echo ""

echo "Bootloop sentinel:"
echo "  strikes:         $(bootloop_count) / $DRESOS_BOOTLOOP_THRESHOLD"
if bootloop_heartbeat_ok; then
    echo "  last boot:       OK"
else
    echo "  last boot:       did not reach service.sh"
fi
for c in zygisk priv_app debloat; do
    if [ -f "$DRESOS_STATE_DIR/disable_$c" ]; then
        echo "  disabled comp:   $c"
    fi
done
echo ""

echo "Managed packages:"
for PKG in $GMS_PKG $CMP_PKG $GSF_PKG $DG_PKG $AS_PKG $APS_PKG; do
    state=$(classify_package_state "$PKG")
    cert=$(installed_cert_sha256 "$PKG")
    printf "  %-32s %s\n" "$PKG" "$state"
    if [ -n "$cert" ]; then
        printf "    cert sha256:  %s\n" "$cert"
    fi
done
echo ""

echo "Regranting runtime permissions"
if is_installed_user0 "$GMS_PKG"; then
    for p in android.permission.ACCESS_COARSE_LOCATION \
             android.permission.ACCESS_FINE_LOCATION \
             android.permission.ACCESS_BACKGROUND_LOCATION \
             android.permission.READ_PHONE_STATE \
             android.permission.GET_ACCOUNTS \
             android.permission.RECEIVE_SMS \
             android.permission.READ_CONTACTS \
             android.permission.READ_EXTERNAL_STORAGE \
             android.permission.POST_NOTIFICATIONS \
             android.permission.FAKE_PACKAGE_SIGNATURE; do
        pm grant "$GMS_PKG" "$p" >/dev/null 2>&1
    done
fi
if is_installed_user0 "$CMP_PKG"; then
    pm grant "$CMP_PKG" android.permission.FAKE_PACKAGE_SIGNATURE >/dev/null 2>&1
fi
if is_installed_user0 "$AS_PKG"; then
    for p in android.permission.READ_EXTERNAL_STORAGE \
             android.permission.WRITE_EXTERNAL_STORAGE \
             android.permission.POST_NOTIFICATIONS; do
        pm grant "$AS_PKG" "$p" >/dev/null 2>&1
    done
fi
if is_installed_user0 "$APS_PKG"; then
    for p in android.permission.INSTALL_PACKAGES \
             android.permission.DELETE_PACKAGES; do
        pm grant "$APS_PKG" "$p" >/dev/null 2>&1
    done
fi
echo "Done."
echo ""

echo "Restarting microG components"
am force-stop "$GMS_PKG"      2>/dev/null
am force-stop "$CMP_PKG"      2>/dev/null
am force-stop "$DG_PKG"       2>/dev/null
echo "Done."
echo ""

echo "Logs at /data/adb/modules/$DRESOS_MODID/logs/"

exit 0
