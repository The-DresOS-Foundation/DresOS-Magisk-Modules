#!/system/bin/sh
##############################################################################
#  DresOS WebView
#  Systemless WebView replacement for Android 10 through 16 and newer
#  dresoperatingsystems.github.io
#
#  Runs once at flash time. Validates the host, selects the WebView engine for
#  the device ABI, drops the signed APK into the systemless tree, and stages a
#  static RRO that whitelists it in config_webview_packages. arm64 uses the
#  DresOS WebView engine; 32-bit arm uses the bundled secondary engine so the
#  module still covers devices the arm64 build cannot, until a 32-bit DresOS
#  WebView build ships. Never calls pm install, never touches real /system.
#  The stock WebView is left intact at flash time and is only disabled later by
#  service.sh, after the engine is confirmed active, and only if opted in.
##############################################################################

ui_print " "
ui_print "==============================================="
ui_print "  DresOS WebView"
ui_print "  Version v2.2.0"
ui_print "  Chromium engine (Cromite based)"
ui_print "  dresoperatingsystems.github.io"
ui_print "==============================================="
ui_print " "

# Stage 1: Magisk version gate (29.0 / 29000 floor).
if [ -z "$MAGISK_VER_CODE" ] || [ "$MAGISK_VER_CODE" -lt 29000 ]; then
    ui_print "! Magisk 29.0 or newer is required."
    ui_print "! Detected Magisk version code: $MAGISK_VER_CODE"
    abort "! Aborting install."
fi
ui_print "  Magisk version code: $MAGISK_VER_CODE"

# Stage 2: Android API gate. Android 10 (29) floor; warn above tested ceiling.
API_LEVEL=$(getprop ro.build.version.sdk)
ANDROID_REL=$(getprop ro.build.version.release)
ui_print "  Android version: $ANDROID_REL (API $API_LEVEL)"
TESTED_MAX_API=36
if [ "$API_LEVEL" -lt 29 ]; then
    ui_print "! Android 10 (API 29) or newer is required."
    abort "! Aborting install."
fi
if [ "$API_LEVEL" -gt "$TESTED_MAX_API" ]; then
    ui_print "! Untested on API $API_LEVEL (tested up to API $TESTED_MAX_API, Android 16)."
    ui_print "! Proceeding anyway. If WebView does not activate, report it at"
    ui_print "! github.com/DresOperatingSystems/DresOS-Magisk-Modules"
fi

# Stage 3: ABI gate. arm64 runs the DresOS WebView engine. 32-bit arm runs the
# bundled secondary engine so the module still covers 32-bit devices the arm64
# build cannot, until a 32-bit DresOS WebView build ships. x86 has no engine.
ABI=$(getprop ro.product.cpu.abi)
ui_print "  Device ABI: $ABI"
case "$ABI" in
    arm64-v8a)
        APK_SRC_NAME="webview-arm64.apk"
        WEBVIEW_PKG="org.dresos.webview"
        ;;
    armeabi-v7a|armeabi)
        APK_SRC_NAME="aosmium-arm32.apk"
        WEBVIEW_PKG="org.axpos.aosmium_wv"
        ;;
    x86|x86_64)
        ui_print "! No x86 WebView engine is bundled in this module."
        abort "! Aborting install."
        ;;
    *)
        ui_print "! Unsupported ABI: $ABI"
        abort "! Aborting install."
        ;;
esac
ui_print "  Selected the WebView engine for this device."
echo "$WEBVIEW_PKG" > "$MODPATH/active_webview_pkg"

# Stage 4: APEX guard.
if ls -d /apex/com.google.android.webview* >/dev/null 2>&1; then
    ui_print "! This device packages WebView as an APEX module."
    ui_print "! Systemless replacement is unsafe in that configuration."
    abort "! Aborting install."
fi
if ls -d /apex/com.android.webview.app* >/dev/null 2>&1; then
    ui_print "! This device packages WebView as an APEX module."
    abort "! Aborting install."
fi

# Stage 5: WebViewUpdateService liveness.
CURRENT_WV=$(dumpsys webviewupdate 2>/dev/null | grep "Current WebView package" | head -1)
if [ -z "$CURRENT_WV" ]; then
    ui_print "! WebViewUpdateService is not responding."
    ui_print "! Refusing to install on a device that already has a broken WebView."
    abort "! Aborting install."
fi
ui_print "  Existing provider: $(echo "$CURRENT_WV" | sed 's/.*Current WebView package //' | tr -d '()')"

# Stage 5b: stale provider detection.
# If the active provider differs from the engine this device will use (for
# example an arm64 device updating off the old AOSmium-only build to the DresOS
# WebView engine), leave a marker so service.sh clears the stale selection
# after boot. A 32-bit device that keeps the same engine clears nothing.
OLD_MOD=/data/adb/modules/dresoswv
OLD_PROVIDER=$(echo "$CURRENT_WV" | sed -n 's/.*(\([^,]*\),.*/\1/p' | tr -d ' ')
NEED_CLEAR=0
if [ -n "$OLD_PROVIDER" ] && [ "$OLD_PROVIDER" != "$WEBVIEW_PKG" ]; then
    case "$OLD_PROVIDER" in
        org.dresos.webview|org.axpos.aosmium_wv) NEED_CLEAR=1 ;;
    esac
fi
if [ -d "$OLD_MOD/system/product/app/AOSmiumWebView" ] && [ "$WEBVIEW_PKG" != "org.axpos.aosmium_wv" ]; then
    NEED_CLEAR=1
fi
if [ "$NEED_CLEAR" -eq 1 ]; then
    ui_print " "
    ui_print "  Switching the active WebView engine on this device."
    touch "$MODPATH/clear_stale_provider"
fi

# Stage 6: Partition layout.
APP_DIR="system/product/app/DresOSWebView"
OVERLAY_DIR="system/product/overlay"
EXTRA_OVERLAY_DIR=""
if [ "$API_LEVEL" -eq 29 ]; then
    EXTRA_OVERLAY_DIR="system/vendor/overlay"
fi
MFG=$(getprop ro.product.manufacturer | tr 'A-Z' 'a-z')
if [ "$MFG" = "samsung" ] && [ -d /system_ext/overlay ]; then
    OVERLAY_DIR="system/system_ext/overlay"
    ui_print "  Samsung One UI detected, using system_ext overlay path."
fi
ui_print "  APK target dir: /$(echo "$APP_DIR" | sed 's|system/||')"
ui_print "  RRO target dir: /$(echo "$OVERLAY_DIR" | sed 's|system/||')"
[ -n "$EXTRA_OVERLAY_DIR" ] && ui_print "  RRO duplicate: /$(echo "$EXTRA_OVERLAY_DIR" | sed 's|system/||')"

# Stage 7: Build the systemless tree.
ui_print "  Building systemless tree."
mkdir -p "$MODPATH/$APP_DIR"
mkdir -p "$MODPATH/$OVERLAY_DIR"
[ -n "$EXTRA_OVERLAY_DIR" ] && mkdir -p "$MODPATH/$EXTRA_OVERLAY_DIR"

APK_SRC="$MODPATH/webview/$APK_SRC_NAME"
if [ ! -f "$APK_SRC" ]; then
    ui_print "! Bundled APK missing: $APK_SRC"
    abort "! Aborting install."
fi
cp -f "$APK_SRC" "$MODPATH/$APP_DIR/DresOSWebView.apk"

RRO_SRC="$MODPATH/overlay/DresOSWebViewOverlay.apk"
if [ ! -f "$RRO_SRC" ]; then
    ui_print "! Bundled overlay missing: $RRO_SRC"
    abort "! Aborting install."
fi
cp -f "$RRO_SRC" "$MODPATH/$OVERLAY_DIR/DresOSWebViewOverlay.apk"
[ -n "$EXTRA_OVERLAY_DIR" ] && cp -f "$RRO_SRC" "$MODPATH/$EXTRA_OVERLAY_DIR/DresOSWebViewOverlay.apk"

# Magisk packs the tree as-is; drop the staging copies.
rm -rf "$MODPATH/webview"
rm -rf "$MODPATH/overlay"

# Stage 8: Permissions and SELinux contexts.
set_perm_recursive "$MODPATH/system" 0 0 0755 0644

# Stage 9: Reset runtime state from any prior install.
rm -f "$MODPATH/boot_pending" 2>/dev/null
rm -f "$MODPATH/inert" 2>/dev/null
rm -f "$MODPATH/disable" 2>/dev/null
mkdir -p "$MODPATH/logs"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Install complete. Awaiting reboot." \
    > "$MODPATH/logs/install.log"

# Stage 9b: Stock WebView removal opt out.
if [ -f /data/adb/dresoswv_keep_stock_webview ]; then
    touch "$MODPATH/keep_stock_webview"
    ui_print "  Opt out file found. Stock WebView will be left enabled."
else
    ui_print "  Stock WebView will be disabled after the engine is confirmed active."
    ui_print "  To keep the stock WebView, create the file"
    ui_print "  /data/adb/dresoswv_keep_stock_webview and reflash."
fi

# Stage 10: Confirmation.
ui_print " "
ui_print "==============================================="
ui_print "  Install complete."
ui_print " "
ui_print "  Reboot to activate the WebView engine."
ui_print "  After boot, verify with:"
ui_print "    adb shell dumpsys webviewupdate | grep Current"
ui_print " "
ui_print "  Activation log:"
ui_print "    /data/adb/modules/dresoswv/logs/service.log"
ui_print "    /data/adb/modules/dresoswv/webview_activation.log"
ui_print "==============================================="
ui_print " "
