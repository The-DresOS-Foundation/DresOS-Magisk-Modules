#!/system/bin/sh
MODDIR=${0%/*}
PENDING=/data/adb/dresos_microg_boot_pending
REASON=/data/adb/dresos_microg_disabled_reason
LIMIT=2

if [ -f "$PENDING" ]; then
    n=$(cat "$PENDING" 2>/dev/null || echo 0)
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    n=$((n + 1))
    if [ "$n" -ge "$LIMIT" ]; then
        : > "$MODDIR/disable"
        rm -f "$PENDING"
        echo "DresOS microG disabled automatically after $n boots that never completed." > "$REASON"
        echo "The most likely cause is a privileged-permission or overlay conflict on this ROM." >> "$REASON"
        echo "Re-enable in the Magisk app once resolved, or open the module Action for details." >> "$REASON"
        exit 0
    fi
    echo "$n" > "$PENDING"
else
    echo 1 > "$PENDING"
fi
exit 0
