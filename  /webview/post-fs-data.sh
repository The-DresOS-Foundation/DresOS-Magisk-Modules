#!/system/bin/sh

MODDIR=${0%/*}
LOG_DIR="$MODDIR/logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/boot.log"
: > "$LOG"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $1" >> "$LOG"; }

log "post-fs-data start"
log "API: $(getprop ro.build.version.sdk)"
log "ABI: $(getprop ro.product.cpu.abi)"
log "Device: $(getprop ro.product.manufacturer) $(getprop ro.product.model)"

if [ -f "$MODDIR/boot_pending" ]; then
    log "STALE boot_pending detected. Previous boot did not finish."
    log "Engaging bootloop fallback."
    touch "$MODDIR/disable"
    touch "$MODDIR/inert"
    rm -f "$MODDIR/boot_pending"
    log "Module disabled. Reboot to recover."
    log "Re enable from the Magisk app once the device is stable."
    exit 0
fi

touch "$MODDIR/boot_pending"
log "boot_pending marker set"

if [ -f "$MODDIR/inert" ]; then
    log "Inert mode flag is set. Skipping any further action this boot."
    exit 0
fi

log "post-fs-data complete. Awaiting boot complete for activation."
exit 0
