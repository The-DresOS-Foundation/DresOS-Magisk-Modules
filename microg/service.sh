#!/system/bin/sh
##############################################################################
#  DresOS microG: service.sh
#
#  Runs late_start, non blocking, in parallel with the rest of device
#  boot. This is where ALL PackageManager state changes happen, well
#  after sys.boot_completed and a settling delay so the framework is
#  fully initialised.
#
#  Jobs, in order:
#    1. Wait for sys.boot_completed plus a 15 second settling delay.
#    2. Aurora Services stale data dir cleanup (idempotent, first boot
#       per install).
#    3. Cert verified self heal pass over every managed package, using
#       remediate_package_runtime with the expected cert from
#       constants.sh. We do NOT uninstall a data overlay if its cert
#       matches our expected cert, which is the case for users who
#       first installed Aurora Services from F-Droid then flashed this
#       module.
#    4. Runtime permission grants for microG and Aurora.
#    5. Optional hardening settings.
#    6. Optional debloat pass via pm disable-user. Runtime disable is
#       reversible and survives reboots via persistent package
#       restrictions, and avoids the boot loop caused by overlaying a
#       priv-app dir that contains an oat/ cache on Android 14 plus.
#    7. UnifiedNlp online location backend selection.
#    8. DresOS default wallpaper one shot apply.
#    9. Heartbeat write so the next boot's post-fs-data sees success.
##############################################################################

MODDIR=${0%/*}
. "$MODDIR/common/constants.sh"
. "$MODDIR/common/functions.sh"

LOG_DIR="$MODDIR/$DRESOS_LOG_DIR_REL"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/service.log"

GMS_PKG="com.google.android.gms"
CMP_PKG="com.android.vending"
GSF_PKG="com.google.android.gsf"
DG_PKG="org.microg.gms.droidguard"
AS_PKG="com.aurora.store"
APS_PKG="com.aurora.services"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $1" >> "$LOG"; }

: > "$LOG"
log "service.sh start"

load_config

if in_safe_mode; then
    log "Safe mode. Skipping activation."
    exit 0
fi

if [ -f "$MODDIR/inert" ]; then
    log "Inert mode. Skipping activation."
    exit 0
fi

resetprop -w sys.boot_completed 0 >/dev/null 2>&1 || {
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
}
log "Boot complete signal received."

sleep 15
log "Settling delay finished."

##############################################################################
#  Aurora Services stale data dir cleanup. First boot per install only.
#
#  Doing this in post-fs-data would race any framework service that
#  already holds a handle to the data dir, so it lives here.
##############################################################################
CLEANED_FLAG="$DRESOS_STATE_DIR/.aurora_data_cleaned"

if [ ! -f "$CLEANED_FLAG" ]; then
    log "First boot Aurora Services data overlay reconciliation"
    aurora_state=$(classify_package_state "$APS_PKG")
    log "  Aurora Services live state: $aurora_state"
    case "$aurora_state" in
        system_with_data_update_enabled|system_with_data_update_disabled)
            log "  Reverting Aurora Services to system priv-app."
            cmd package uninstall -k --user 0 "$APS_PKG" >/dev/null 2>&1
            sleep 2
            cmd package install-existing --user 0 "$APS_PKG" >/dev/null 2>&1
            ;;
        data_only)
            log "  Aurora Services data only; system overlay did not land. Leaving user copy intact."
            ;;
        *)
            log "  No data overlay reconciliation needed for Aurora Services."
            ;;
    esac
    mkdir -p "$DRESOS_STATE_DIR" 2>/dev/null
    touch "$CLEANED_FLAG"
fi

##############################################################################
#  Cert verified self heal pass.
##############################################################################
stage_marker_set pms_remediate

if [ -f "$DRESOS_STATE_DIR/disable_priv_app" ]; then
    log "disable_priv_app flag set. Skipping PMS remediation this boot."
else
    log "PMS remediation pass"
    echo "$DRESOS_STAGING_TABLE" | while IFS='|' read -r pkg apkname dirname cert; do
        [ -z "$pkg" ] && continue
        before=$(classify_package_state "$pkg")
        live_cert=$(installed_cert_sha256 "$pkg")
        case "$before" in
            none)
                log "  $pkg: not registered (overlay did not land). Skipping."
                ;;
            system_only_enabled)
                if [ -n "$live_cert" ] && [ "$live_cert" = "$cert" ]; then
                    log "  $pkg: system_only_enabled, cert matches. Perfect."
                elif [ -n "$live_cert" ] && [ "$live_cert" != "$cert" ]; then
                    log "  $pkg: system_only_enabled but cert MISMATCH ($live_cert)."
                    log "    ROM ships a different signed copy. Not touching."
                else
                    log "  $pkg: system_only_enabled, cert unknown. Leaving alone."
                fi
                ;;
            *)
                after=$(remediate_package_runtime "$pkg" "$cert")
                log "  $pkg: $before -> $after"
                ;;
        esac
    done
fi

stage_marker_clear pms_remediate

##############################################################################
#  microG runtime permission grants. Idempotent. Safe to repeat boots.
##############################################################################
if is_installed_user0 "$GMS_PKG"; then
    for p in android.permission.ACCESS_COARSE_LOCATION \
             android.permission.ACCESS_FINE_LOCATION \
             android.permission.ACCESS_BACKGROUND_LOCATION \
             android.permission.READ_PHONE_STATE \
             android.permission.GET_ACCOUNTS \
             android.permission.RECEIVE_SMS \
             android.permission.READ_CONTACTS \
             android.permission.READ_EXTERNAL_STORAGE \
             android.permission.POST_NOTIFICATIONS; do
        pm grant "$GMS_PKG" "$p" >/dev/null 2>&1
    done
    pm grant "$GMS_PKG" android.permission.FAKE_PACKAGE_SIGNATURE >/dev/null 2>&1
    log "microG runtime permissions granted (FAKE_PACKAGE_SIGNATURE attempted)"
else
    log "microG ($GMS_PKG) not yet visible to PMS; skipping grants this boot"
fi

if is_installed_user0 "$CMP_PKG"; then
    pm grant "$CMP_PKG" android.permission.FAKE_PACKAGE_SIGNATURE >/dev/null 2>&1
fi

##############################################################################
#  Aurora runtime permission grants.
##############################################################################
if is_installed_user0 "$AS_PKG"; then
    for p in android.permission.READ_EXTERNAL_STORAGE \
             android.permission.WRITE_EXTERNAL_STORAGE \
             android.permission.POST_NOTIFICATIONS; do
        pm grant "$AS_PKG" "$p" >/dev/null 2>&1
    done
    log "Aurora Store runtime permissions granted"
fi

if is_installed_user0 "$APS_PKG"; then
    for p in android.permission.INSTALL_PACKAGES \
             android.permission.DELETE_PACKAGES; do
        pm grant "$APS_PKG" "$p" >/dev/null 2>&1
    done
    log "Aurora Services privileged permission grants attempted (XML is authoritative)"
fi

##############################################################################
#  Hardening settings.
##############################################################################
if [ "$DRESOS_HARDEN_ENABLE" = "1" ]; then
    apply_hardening_settings
    log "Hardening settings applied (best effort)"
fi

##############################################################################
#  Debloat pass via pm disable user.
#
#  Debloat is RUNTIME, not systemless. Each bloat package is disabled
#  for user 0 using `pm disable-user --user 0 <pkg>`. The disable state
#  is persisted in /data/system/users/0/package-restrictions.xml and
#  survives reboots. Reversible by `pm enable` or by uninstalling this
#  module (uninstall re enables every package the module disabled).
##############################################################################
if [ "$DRESOS_DEBLOAT_ENABLE" = "1" ] \
   && [ ! -f "$DRESOS_STATE_DIR/disable_debloat" ]; then
    stage_marker_set debloat
    log "Runtime debloat pass"
    disabled_count=0
    : > "$DRESOS_STATE_DIR/disabled_pkgs.txt"
    for pkg in $DRESOS_DEBLOAT_PKGS; do
        if is_installed_user0 "$pkg"; then
            if pm disable-user --user 0 "$pkg" >/dev/null 2>&1; then
                echo "$pkg" >> "$DRESOS_STATE_DIR/disabled_pkgs.txt"
                disabled_count=$((disabled_count + 1))
                log "  disabled $pkg"
            fi
        fi
    done
    log "  $disabled_count package(s) disabled for user 0"
    stage_marker_clear debloat
elif [ -f "$DRESOS_STATE_DIR/disable_debloat" ]; then
    log "disable_debloat flag set. Skipping debloat pass."
fi

##############################################################################
#  Online location backend selection.
##############################################################################
case "$DRESOS_AURORA_BACKEND" in
    beacondb)
        settings put global microg.nlp.geocoder.url \
            https://api.beacondb.net/v1/geolocate >/dev/null 2>&1 || true
        log "beaconDB configured as online location backend"
        ;;
    none)
        settings delete global microg.nlp.geocoder.url >/dev/null 2>&1 || true
        log "Online location backend cleared per config"
        ;;
    *)
        log "Unknown aurora_backend=$DRESOS_AURORA_BACKEND, leaving location backend alone"
        ;;
esac

##############################################################################
#  Wallpaper one time apply.
##############################################################################
WP_FLAG="$MODDIR/.needs_first_boot_wallpaper"
WP_DONE="$DRESOS_STATE_DIR/.wallpaper_applied"
WP_SRC="$MODDIR/wallpapers/dresos_default.jpg"
USER_DIR=/data/system/users/0

if [ "$DRESOS_WALLPAPER_ENABLE" = "1" ] \
   && [ -f "$WP_FLAG" ] && [ ! -f "$WP_DONE" ] && [ -f "$WP_SRC" ]; then
    log "Wallpaper apply: starting"
    OUR_SIZE=$(stat -c '%s' "$WP_SRC" 2>/dev/null)
    EXIST_SIZE=""
    [ -f "$USER_DIR/wallpaper" ] && EXIST_SIZE=$(stat -c '%s' "$USER_DIR/wallpaper" 2>/dev/null)

    if [ -n "$EXIST_SIZE" ] && [ "$EXIST_SIZE" != "$OUR_SIZE" ] \
       && [ "$EXIST_SIZE" -gt 10000 ]; then
        log "  Existing user wallpaper detected (size $EXIST_SIZE, ours $OUR_SIZE)"
        log "  Respecting user choice. Marking as applied."
    else
        cp -f "$WP_SRC" "$USER_DIR/wallpaper"      2>/dev/null
        cp -f "$WP_SRC" "$USER_DIR/wallpaper_lock" 2>/dev/null
        cat > "$USER_DIR/wallpaper_info.xml" <<'XMLEOF'
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<wp width="1080" height="2400" cropLeft="0" cropTop="0" cropRight="1080" cropBottom="2400" name="" id="1" />
<kwp width="1080" height="2400" cropLeft="0" cropTop="0" cropRight="1080" cropBottom="2400" name="" id="2" />
XMLEOF
        chown system:system "$USER_DIR/wallpaper" \
              "$USER_DIR/wallpaper_lock" "$USER_DIR/wallpaper_info.xml" 2>/dev/null
        chmod 0600 "$USER_DIR/wallpaper" "$USER_DIR/wallpaper_lock" 2>/dev/null
        chmod 0644 "$USER_DIR/wallpaper_info.xml" 2>/dev/null
        chcon u:object_r:system_data_file:s0 "$USER_DIR/wallpaper" \
              "$USER_DIR/wallpaper_lock" "$USER_DIR/wallpaper_info.xml" 2>/dev/null
        log "  DresOS default wallpaper written"
    fi

    touch "$WP_DONE"
    rm -f "$WP_FLAG"
    log "Wallpaper apply: complete (one shot)"
fi

##############################################################################
#  Visibility sanity check.
##############################################################################
ok=0; warn=0
for PKG in $GMS_PKG $CMP_PKG $GSF_PKG $DG_PKG $AS_PKG $APS_PKG; do
    if is_installed_user0 "$PKG"; then
        ok=$((ok + 1))
        log "  visible:    $PKG"
    else
        warn=$((warn + 1))
        log "  not yet:    $PKG"
    fi
done
log "Visibility: $ok visible, $warn pending"

bootloop_heartbeat_write
log "Heartbeat written. service.sh end."

exit 0
