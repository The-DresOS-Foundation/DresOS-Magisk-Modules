#!/system/bin/sh
MODDIR=${0%/*}
PENDING=/data/adb/dresos_microg_boot_pending

(
    i=0
    while [ "$i" -lt 120 ]; do
        [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && break
        sleep 1
        i=$((i + 1))
    done
    sleep 5
    rm -f "$PENDING"
) &
exit 0
