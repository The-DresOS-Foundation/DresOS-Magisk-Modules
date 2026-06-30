#!/system/bin/sh
##############################################################################
#  DresOS microG  service.sh   (clears the bootloop watchdog flag)
#
#  Runs in late_start service mode. Waits for the system to finish booting,
#  then clears the pending flag raised in post-fs-data.sh. Reaching this
#  point proves the module did not bootloop the device, so the watchdog
#  stays armed but does not trip. Nothing else happens here: no PackageManager
#  work, no debloat, no other-module changes.
##############################################################################
MODDIR=${0%/*}
PENDING=/data/adb/dresos_microg_boot_pending

(
    i=0
    while [ "$i" -lt 120 ]; do
        [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && break
        sleep 1
        i=$((i + 1))
    done
    # Give PackageManager a moment to settle after boot_completed, then disarm.
    sleep 5
    rm -f "$PENDING"
) &
exit 0
