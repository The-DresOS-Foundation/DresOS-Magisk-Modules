#!/system/bin/sh
##############################################################################
#  DresOS microG: post-fs-data.sh
#
#  Runs blocking, before zygote, before service activation.
#
#  Single job: heartbeat driven bootloop sentinel. Does NOT touch PMS,
#  does NOT delete app data, does NOT scan APKs. Anything heavy here
#  blocks the device from reaching the lock screen.
#
#  Heartbeat logic:
#    - On a clean first boot post install, last_boot_ok_epoch does not
#      exist yet. Treat as healthy.
#    - On subsequent boots, last_boot_ok_epoch must be >= installed_at_epoch.
#      If it is older, the previous boot never reached service.sh's end
#      of run, count a strike.
#    - At DRESOS_BOOTLOOP_THRESHOLD strikes, disable the module by
#      planting MODDIR/disable. Magisk will skip mounting the systemless
#      overlay on the next boot.
#
#  Per component disable on top of the global counter: if a stage marker
#  from a prior boot is still present, that stage is implicated and we
#  drop a disable_<stage> flag. service.sh consults those on its next
#  run and skips just the broken component instead of disabling the
#  whole module.
##############################################################################

MODDIR=${0%/*}
. "$MODDIR/common/constants.sh"
. "$MODDIR/common/functions.sh"

LOG_DIR="$MODDIR/$DRESOS_LOG_DIR_REL"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/boot.log"

: > "$LOG"
ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $1" >> "$LOG"; }

log "post-fs-data start"
log "API: $(getprop ro.build.version.sdk)"
log "ABI: $(getprop ro.product.cpu.abi)"
log "Device: $(getprop ro.product.manufacturer) $(getprop ro.product.model)"

if in_safe_mode; then
    log "Safe mode detected. Skipping all activation."
    exit 0
fi

##############################################################################
#  Heartbeat driven bootloop sentinel.
##############################################################################
if bootloop_heartbeat_ok; then
    prior=$(bootloop_count)
    if [ "$prior" -ne 0 ]; then
        bootloop_clear
        log "Previous boot completed. Cleared $prior prior strike(s)."
    else
        log "Previous boot completed. Strike count remains 0."
    fi
else
    strike=$(bootloop_strike)
    log "Previous boot did NOT reach service.sh. Strike $strike / $DRESOS_BOOTLOOP_THRESHOLD."

    if stage_marker_check zygisk_load; then
        log "  Stage marker zygisk_load present from prior boot. Disabling Zygisk component."
        touch "$DRESOS_STATE_DIR/disable_zygisk"
        stage_marker_clear zygisk_load
    fi
    if stage_marker_check pms_remediate; then
        log "  Stage marker pms_remediate present from prior boot. Disabling PMS remediation."
        touch "$DRESOS_STATE_DIR/disable_priv_app"
        stage_marker_clear pms_remediate
    fi
    if stage_marker_check debloat; then
        log "  Stage marker debloat present from prior boot. Disabling debloat pass."
        touch "$DRESOS_STATE_DIR/disable_debloat"
        stage_marker_clear debloat
    fi

    if [ "$strike" -ge "$DRESOS_BOOTLOOP_THRESHOLD" ]; then
        log "STRIKE LIMIT REACHED. Disabling module entirely."
        log "Reset by removing $DRESOS_STATE_DIR/bootloop_count and"
        log "$DRESOS_STATE_DIR/last_boot_ok_epoch then rebooting,"
        log "or reinstall the module."
        touch "$MODDIR/disable"
        exit 0
    fi
fi

if [ -f "$MODDIR/inert" ]; then
    log "Inert flag present. Module mounted but no further work this boot."
    exit 0
fi

##############################################################################
#  Zygisk early gate. If a previous boot fingered the Zygisk hook as the
#  implicated stage, stash the payload so it does not mount this boot.
##############################################################################
if [ -f "$DRESOS_STATE_DIR/disable_zygisk" ] && [ -d "$MODDIR/zygisk" ]; then
    log "disable_zygisk flag set. Stashing Zygisk payload for this boot."
    rm -rf "$MODDIR/.zygisk_stash" 2>/dev/null
    mv "$MODDIR/zygisk" "$MODDIR/.zygisk_stash" 2>/dev/null
fi

log "post-fs-data done. Awaiting boot complete."
exit 0
