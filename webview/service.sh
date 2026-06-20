#!/system/bin/sh
##############################################################################
#  DresOS WebView: service.sh   (late_start, non blocking)
#
#  Waits for boot, confirms the selected WebView engine is visible, promotes it
#  to the active WebView provider via cmd webviewupdate, verifies via dumpsys,
#  then (unless opted out) disables the stock WebView and plants a recovery-safe
#  restore trampoline. Flips to inert mode on any failure so it cannot
#  bootloop. Google Chrome and the Trichrome library are never touched.
##############################################################################

MODDIR=${0%/*}
LOG_DIR="$MODDIR/logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/service.log"
USER_LOG="$MODDIR/webview_activation.log"

# Engine selected at flash time by customize.sh (org.dresos.webview on arm64,
# org.axpos.aosmium_wv on 32-bit arm). Default to DresOS WebView if missing.
WEBVIEW_PKG=$(cat "$MODDIR/active_webview_pkg" 2>/dev/null | tr -d ' \n')
[ -z "$WEBVIEW_PKG" ] && WEBVIEW_PKG="org.dresos.webview"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() {
    echo "[$(ts)] $1" >> "$LOG"
    echo "[$(ts)] $1" >> "$USER_LOG"
}

log "service.sh start"
log "Target WebView engine: $WEBVIEW_PKG"

resetprop -w sys.boot_completed 0 >/dev/null 2>&1
log "Boot complete signal received."
sleep 10

if [ -f "$MODDIR/inert" ]; then
    log "Inert mode is set. Skipping activation."
    rm -f "$MODDIR/boot_pending"
    exit 0
fi

VISIBLE=$(pm list packages "$WEBVIEW_PKG" 2>/dev/null | grep -c "^package:${WEBVIEW_PKG}$")
if [ "$VISIBLE" -ne 1 ]; then
    log "FAIL: PackageManager does not see $WEBVIEW_PKG."
    log "Likely cause: RRO did not register or APK bind mount did not land."
    log "Flipping module to inert mode."
    touch "$MODDIR/inert"
    rm -f "$MODDIR/boot_pending"
    exit 0
fi
log "PackageManager sees $WEBVIEW_PKG"

# Clear a stale provider selection when the engine changed (for example an
# arm64 device that updated off the old AOSmium-only build). The marker is set
# by customize.sh. Also clear directly if the saved provider points at a
# managed engine other than the one this device now uses. A device that keeps
# the same engine clears nothing.
PREV_PROVIDER=$(settings get global webview_provider 2>/dev/null | tr -d ' ')
CLEAR=0
[ -f "$MODDIR/clear_stale_provider" ] && CLEAR=1
if [ -n "$PREV_PROVIDER" ] && [ "$PREV_PROVIDER" != "$WEBVIEW_PKG" ]; then
    case "$PREV_PROVIDER" in
        org.dresos.webview|org.axpos.aosmium_wv) CLEAR=1 ;;
    esac
fi
if [ "$CLEAR" -eq 1 ]; then
    log "Engine switch: clearing stale provider selection '$PREV_PROVIDER'."
    settings delete global webview_provider 2>/dev/null
    rm -f "$MODDIR/clear_stale_provider" 2>/dev/null
fi

cmd webviewupdate enable-redundant-packages >> "$LOG" 2>&1
SETIMPL_OUT=$(cmd webviewupdate set-webview-implementation "$WEBVIEW_PKG" 2>&1)
log "cmd webviewupdate set-webview-implementation: $SETIMPL_OUT"
settings put global webview_provider "$WEBVIEW_PKG" 2>>"$LOG"

sleep 3
CURRENT=$(dumpsys webviewupdate 2>/dev/null \
    | sed -n 's/.*Current WebView package[^:]*: (\([^,)]*\).*/\1/p' \
    | head -1 | tr -d ' ')

if [ "$CURRENT" = "$WEBVIEW_PKG" ]; then
    log "SUCCESS: Active WebView provider is now $WEBVIEW_PKG"
    log "Activation complete."

    if [ -f "$MODDIR/keep_stock_webview" ]; then
        log "Opt out marker present. Leaving stock WebView enabled."
    else
        STOCK_WV=""
        if pm path com.google.android.webview >/dev/null 2>&1; then
            STOCK_WV="com.google.android.webview"
        elif pm path com.android.webview >/dev/null 2>&1; then
            STOCK_WV="com.android.webview"
        fi

        if [ -z "$STOCK_WV" ]; then
            log "No stock WebView package found to disable. Nothing to do."
        elif [ "$STOCK_WV" = "$WEBVIEW_PKG" ]; then
            log "Stock probe resolved to the active engine itself. Skipping disable."
        else
            log "Disabling stock WebView package: $STOCK_WV"
            DIS_OUT=$(pm disable-user --user 0 "$STOCK_WV" 2>&1)
            log "pm disable-user: $DIS_OUT"

            ENABLED_STATE=$(dumpsys package "$STOCK_WV" 2>/dev/null \
                | grep -m1 "enabled=" | tr -d ' ')
            log "Post disable state: $ENABLED_STATE"

            sleep 2
            RECHECK=$(dumpsys webviewupdate 2>/dev/null \
                | sed -n 's/.*Current WebView package[^:]*: (\([^,)]*\).*/\1/p' \
                | head -1 | tr -d ' ')
            if [ "$RECHECK" = "$WEBVIEW_PKG" ]; then
                log "Confirmed: the active engine is still active after disabling $STOCK_WV."
                echo "$STOCK_WV" > "$MODDIR/disabled_stock_webview"

                TRAMP_DIR=/data/adb/post-fs-data.d
                TRAMP="$TRAMP_DIR/zz_dresoswv_restore_wv.sh"
                mkdir -p "$TRAMP_DIR" 2>/dev/null
                {
                    echo '#!/system/bin/sh'
                    echo '# DresOS WebView stock restore trampoline.'
                    echo '# Only acts if the DresOS module is gone. Self deletes.'
                    echo 'MODD=/data/adb/modules/dresoswv'
                    echo '[ -d "$MODD" ] && exit 0'
                    echo '('
                    echo '  until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done'
                    echo '  sleep 10'
                    echo "  pm enable $STOCK_WV"
                    echo '  pm enable com.google.android.webview 2>/dev/null'
                    echo '  pm enable com.android.webview 2>/dev/null'
                    echo '  settings delete global webview_provider 2>/dev/null'
                    echo '  rm -- "$0"'
                    echo ') &'
                } > "$TRAMP"
                chmod 0755 "$TRAMP" 2>/dev/null
                log "Restore trampoline planted at $TRAMP"
            else
                log "WARNING: the active engine is no longer active after disable."
                log "Re enabling $STOCK_WV to keep the device safe."
                pm enable "$STOCK_WV" >> "$LOG" 2>&1
                touch "$MODDIR/inert"
            fi
        fi
    fi
else
    log "FAIL: Active provider is '$CURRENT', expected '$WEBVIEW_PKG'."
    log "Possible causes:"
    log "  RRO loaded but signature mismatch on the engine APK."
    log "  Engine versionCode below preinstalled provider (unlikely)."
    log "  OEM lock that prevents non OEM WebView providers."
    log "Flipping module to inert mode."
    touch "$MODDIR/inert"
fi

rm -f "$MODDIR/boot_pending"
log "service.sh end"
exit 0
