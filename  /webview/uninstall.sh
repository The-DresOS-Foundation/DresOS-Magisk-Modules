#!/system/bin/sh

MODDIR=${0%/*}

settings delete global webview_provider 2>/dev/null

STOCK_WV=""
if [ -f "$MODDIR/disabled_stock_webview" ]; then
    STOCK_WV=$(cat "$MODDIR/disabled_stock_webview" 2>/dev/null)
fi

if [ -n "$STOCK_WV" ]; then
    pm enable "$STOCK_WV" 2>/dev/null
fi
pm enable com.google.android.webview 2>/dev/null
pm enable com.android.webview 2>/dev/null

if pm list packages 2>/dev/null | grep -q "^package:com.google.android.webview$"; then
    cmd webviewupdate set-webview-implementation com.google.android.webview 2>/dev/null
elif pm list packages 2>/dev/null | grep -q "^package:com.android.webview$"; then
    cmd webviewupdate set-webview-implementation com.android.webview 2>/dev/null
fi

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
    [ -n "$STOCK_WV" ] && echo "  pm enable $STOCK_WV"
    echo '  pm enable com.google.android.webview 2>/dev/null'
    echo '  pm enable com.android.webview 2>/dev/null'
    echo '  settings delete global webview_provider 2>/dev/null'
    echo '  rm -- "$0"'
    echo ') &'
} > "$TRAMP"
chmod 0755 "$TRAMP" 2>/dev/null

exit 0
