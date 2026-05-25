#!/system/bin/sh
##############################################################################
#  DresOS microG: uninstall.sh
#
#  Runs when the user removes the module from the Magisk app or by
#  flashing an empty replacement. Three jobs:
#    1. Re enable every package this module disabled during debloat.
#    2. Revert hardening settings best effort.
#    3. Drop the persistent state dir under /data/adb/.
##############################################################################

MODDIR=${0%/*}
. "$MODDIR/common/constants.sh"
. "$MODDIR/common/functions.sh"

LOG_DIR="$MODDIR/$DRESOS_LOG_DIR_REL"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/uninstall.log"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $1" >> "$LOG"; }

: > "$LOG"
log "uninstall.sh start"

##############################################################################
#  Re enable previously disabled packages. Read the canonical list of what
#  this module disabled rather than blindly enabling the entire static
#  catalogue, so we never re enable a package the user themselves
#  disabled for other reasons.
##############################################################################
if [ -f "$DRESOS_STATE_DIR/disabled_pkgs.txt" ]; then
    log "Re enabling previously disabled packages"
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if pm enable --user 0 "$pkg" >/dev/null 2>&1; then
            log "  enabled $pkg"
        fi
    done < "$DRESOS_STATE_DIR/disabled_pkgs.txt"
fi

##############################################################################
#  Revert hardening settings best effort.
##############################################################################
if [ -f "$DRESOS_STATE_DIR/harden_enabled" ] \
   && [ "$(cat "$DRESOS_STATE_DIR/harden_enabled")" = "1" ]; then
    log "Reverting hardening settings"
    revert_hardening_settings
fi

##############################################################################
#  Drop managed user data ONLY if the package itself was uninstalled.
#  We do not clear running app data here; clearing GmsCore data while
#  the framework is still binding to it leads to sad system services.
##############################################################################
log "Trampoline: package data is left intact. Reboot to fully release."

##############################################################################
#  State dir cleanup.
##############################################################################
rm -rf "$DRESOS_STATE_DIR" 2>/dev/null
log "State dir removed: $DRESOS_STATE_DIR"

log "uninstall.sh end"
exit 0
