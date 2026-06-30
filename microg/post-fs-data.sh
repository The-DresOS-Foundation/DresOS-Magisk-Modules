#!/system/bin/sh
##############################################################################
#  DresOS microG  post-fs-data.sh   (bootloop self-recovery watchdog ONLY)
#
#  This is the ONLY code this module runs early at boot, and it does exactly
#  one thing: protect you from a bootloop. It does NOT run Zygisk, does NOT
#  touch PackageManager, does NOT debloat anything, and does NOT touch any
#  other module. It only ever writes its own module's "disable" file.
#
#  How it works: each boot we raise a pending flag here. service.sh clears
#  that flag only after the system fully boots (sys.boot_completed=1). So if
#  a boot dies before completing (for example system_server crashes on a
#  privileged-permission mismatch), the flag is still raised on the next
#  boot. After two such failed boots in a row we disable this module so the
#  device boots cleanly without it, and leave a reason file you can read.
##############################################################################
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
