#!/system/bin/sh
##############################################################################
#  DresOS microG: common/functions.sh
#
#  Runtime utility library. Sourced by customize.sh, post-fs-data.sh,
#  service.sh, action.sh, and uninstall.sh. POSIX sh only, busybox safe.
#
#  Design contract:
#    - No function in this file mutates PackageManager state at install
#      time. PMS mutations live in service.sh, which runs after
#      sys.boot_completed and a settling delay. customize.sh only stages
#      files and writes state records.
#    - Cert comparison is done against the X.509 cert SHA 256 that PMS
#      computes itself, via `cmd package dump <pkg>`. No on device APK
#      parsing. This is the only reliable on device approach.
##############################################################################

##  Guard against double source.
if [ -z "$MICROG_UPSTREAM_CERT" ]; then
    _here=$(dirname "$0")
    if   [ -f "$_here/constants.sh" ];        then . "$_here/constants.sh"
    elif [ -f "$_here/common/constants.sh" ]; then . "$_here/common/constants.sh"
    elif [ -n "$MODPATH" ] && [ -f "$MODPATH/common/constants.sh" ]; then
        . "$MODPATH/common/constants.sh"
    elif [ -n "$MODDIR" ] && [ -f "$MODDIR/common/constants.sh" ]; then
        . "$MODDIR/common/constants.sh"
    fi
fi

GP() { getprop "$1" 2>/dev/null; }

##############################################################################
#  pick_priv_app_partition <api_level>
#
#  Returns the priv-app partition our APKs and XMLs should land in.
#  Android 9 plus  (API 28 plus) recognises /system/product as a real
#  partition for added priv-apps and the same partition rule applies:
#  if the APK is under /system/product/priv-app/<x>/ the matching
#  privapp-permissions XML MUST be under /system/product/etc/permissions/.
#  On API 26 and 27 (Android 8 and 8.1) /system/product is not part of
#  the standard partition set, so we fall back to /system. We deliberately
#  do NOT use /system/system_ext: it exists from Android 11 plus only, was
#  never part of the same partition contract before that, and several
#  OEM ROMs lock it down with stricter SELinux contexts that priv-app
#  scanning treats inconsistently.
##############################################################################
pick_priv_app_partition() {
    api="$1"
    if [ "$api" -ge 28 ]; then
        echo "system/product"
    else
        echo "system"
    fi
}

##############################################################################
#  detect_rom: best effort ROM detection, used for log lines and for the
#  native sigspoof and native microG probes. Never abort on detection
#  result alone, with the single GrapheneOS exception handled separately.
##############################################################################
detect_rom() {
    [ -n "$(GP ro.iode.version)" ] && echo "iode" && return
    if [ -n "$(GP ro.e.version)" ] || [ -d /system/priv-app/eDrive ] \
       || { [ -n "$(GP ro.lineageos.build_version)" ] \
            && [ "$(GP ro.build.user)" = "e_developer" ]; }; then
        echo "eos"; return
    fi
    if [ -n "$(GP ro.calyxos.version)" ] \
       || { [ -d /system/priv-app/SeedVault ] \
            && grep -qi calyx /system/build.prop 2>/dev/null; } \
       || { [ -d /product/priv-app/GmsCore ] \
            && grep -qi calyx /system/build.prop 2>/dev/null; }; then
        echo "calyxos"; return
    fi
    if [ -n "$(GP ro.lineage.version)" ] \
       && echo "$(GP ro.lineage.releasetype)$(GP ro.build.host)" \
          | grep -qi divest; then
        echo "divestos"; return
    fi
    if [ -n "$(GP ro.lineage.version)" ] || [ -n "$(GP ro.cm.version)" ]; then
        if [ -d /system/priv-app/GmsCore ] \
           || [ -d /system/priv-app/MicroGGmsCore ] \
           || [ -d /system/priv-app/GsfProxy ] \
           || [ -d /product/priv-app/GmsCore ] \
           || [ -d /product/priv-app/MicroGGmsCore ] \
           || [ -n "$(GP ro.microg.device)" ]; then
            echo "lineage_microg"; return
        fi
        echo "lineage"; return
    fi
    if [ "$(GP ro.product.manufacturer)" = "Google" ] \
       && { [ -d /system/app/GrapheneOSCamera ] \
            || [ -d /system/priv-app/Auditor ] \
            || grep -qi grapheneos /system/build.prop 2>/dev/null \
            || [ -f /system/etc/grapheneos-release ]; }; then
        echo "grapheneos"; return
    fi
    [ -n "$(GP ro.build.version.oneui)" ]    && echo "oneui"     && return
    [ -n "$(GP ro.mi.os.version.name)" ]     && echo "hyperos"   && return
    [ -n "$(GP ro.miui.ui.version.name)" ]   && echo "miui"      && return
    [ -n "$(GP ro.oxygen.version)" ]         && echo "oxygen"    && return
    GP ro.build.version.ota | grep -qi oxygen && echo "oxygen"   && return
    [ -n "$(GP ro.build.version.opporom)" ]  && echo "coloros"   && return
    [ -n "$(GP ro.build.version.oplusrom)" ] && echo "coloros"   && return
    [ -n "$(GP ro.build.version.realmeui)" ] && echo "realmeui"  && return
    [ -n "$(GP ro.vivo.os.version)" ]        && echo "funtouch"  && return
    GP hw_sc.build.platform.version | grep -q . \
        && echo "harmonyos" && return
    [ -n "$(GP ro.build.version.emui)" ]     && echo "emui"      && return
    [ -n "$(GP ro.nothing.version)" ]        && echo "nothingos" && return
    [ -n "$(GP ro.semc.product.name)" ]      && echo "sony"      && return
    [ -n "$(GP ro.asus.zenui.version)" ]     && echo "zenui"     && return
    [ "$(GP ro.product.manufacturer)" = "motorola" ] && echo "motorola" && return
    [ "$(GP ro.product.brand)" = "Fairphone" ]       && echo "fairphone" && return
    if [ "$(GP ro.product.manufacturer)" = "Google" ] \
       && { [ -d /system/priv-app/Phonesky ] \
            || [ -d /system/priv-app/PrebuiltGmsCore ] \
            || [ -d /system/priv-app/PrebuiltGmsCorePix ]; }; then
        echo "pixel_stock"; return
    fi
    if [ ! -d /system/priv-app/Phonesky ] \
       && [ ! -d /system/priv-app/PrebuiltGmsCore ]; then
        echo "aosp"; return
    fi
    echo "unknown"
}

##############################################################################
#  is_grapheneos: hard refuse path. GrapheneOS deliberately refuses
#  signature spoofing at the framework level and recommends Sandboxed
#  Google Play. Installing this module there could only weaken security.
##############################################################################
is_grapheneos() {
    [ -f /system/etc/grapheneos-release ] && return 0
    [ -d /system/app/GrapheneOSCamera ]   && return 0
    [ -d /system/priv-app/Auditor ]       && return 0
    GP ro.build.fingerprint | grep -qi grapheneos && return 0
    GP ro.build.flavor      | grep -qi grapheneos && return 0
    grep -qi grapheneos /system/build.prop 2>/dev/null && return 0
    return 1
}

##############################################################################
#  rom_provides_sigspoof: returns 0 if the ROM patches PackageManager to
#  spoof Google signatures. When in doubt, false, so the Zygisk fallback
#  stays. CalyxOS specifically renamed FAKE_PACKAGE_SIGNATURE to
#  MICROG_SPOOF_SIGNATURE and hardcoded the allowed package list; their
#  spoof is still native and we should not double up.
##############################################################################
rom_provides_sigspoof() {
    [ -n "$(GP ro.calyxos.version)" ]       && return 0
    [ -n "$(GP ro.iode.version)" ]          && return 0
    [ -n "$(GP ro.e.version)" ]             && return 0
    [ -n "$(GP ro.divest.version)" ]        && return 0
    if [ -n "$(GP ro.lineage.version)" ]; then
        if [ -d /system/priv-app/GmsCore ] \
           || [ -d /system/priv-app/MicroGGmsCore ] \
           || [ -d /product/priv-app/GmsCore ] \
           || [ -n "$(GP ro.microg.device)" ]; then
            return 0
        fi
    fi
    return 1
}

##############################################################################
#  is_aosmium_active: returns 0 if the DresOS AOSmium WebView module is
#  installed and enabled. Informational only.
##############################################################################
is_aosmium_active() {
    for d in /data/adb/modules/DresOS-AOSmium-WebView \
             /data/adb/modules/dresoswv \
             /data/adb/modules/AOSmium-WebView \
             /data/adb/modules/aosmium-webview; do
        [ -d "$d" ] && [ ! -f "$d/disable" ] && [ ! -f "$d/remove" ] \
            && return 0
    done
    return 1
}

in_safe_mode() {
    [ "$(GP persist.sys.safemode)" = "1" ] && return 0
    [ -f /cache/.disable_magisk ]       && return 0
    [ -f /data/cache/.disable_magisk ]  && return 0
    return 1
}

##############################################################################
#  rom_ships_working_microg <pkg>
#
#  Returns 0 if the ROM has <pkg> registered as a system priv-app. This
#  is the safe signal that we should NOT stage our own copy of microG.
#  We only call this at install time as a heuristic, then refine post
#  boot in service.sh once `cmd package dump` is reliably authoritative.
##############################################################################
rom_ships_working_microg() {
    pkg="$1"
    p=$(pm path "$pkg" 2>/dev/null | head -1 | sed 's|^package:||')
    case "$p" in
        /system/*|/system_ext/*|/product/*|/vendor/*|/odm/*|/apex/*) : ;;
        *) return 1 ;;
    esac
    return 0
}

##############################################################################
#  PackageManager helpers.
##############################################################################
is_installed_user0() {
    pm list packages --user 0 2>/dev/null | grep -q "^package:$1\$"
}

pkg_apk_path() {
    pm path "$1" 2>/dev/null | head -1 | sed 's|^package:||'
}

pkg_system_path_any() {
    pkg="$1"
    p=$(pm path "$pkg" 2>/dev/null \
            | sed 's|^package:||' \
            | grep -E '^/(system|system_ext|product|vendor|odm|apex)/' \
            | head -1)
    if [ -n "$p" ]; then echo "$p"; return; fi
    cmd package list packages -u -s -f 2>/dev/null \
        | grep "=${pkg}\$" \
        | head -1 \
        | sed 's|^package:||; s|=[^=]*$||' \
        | grep -E '^/(system|system_ext|product|vendor|odm|apex)/'
}

has_data_app_overlay() {
    pkg="$1"
    paths=$(pm path "$pkg" 2>/dev/null | sed 's|^package:||')
    [ -z "$paths" ] && return 1
    for p in $paths; do
        case "$p" in
            /data/app/*) return 0 ;;
        esac
    done
    return 1
}

##############################################################################
#  installed_cert_sha256 <pkg>
#
#  Returns the X.509 cert SHA 256 fingerprint that PackageManager reports
#  for <pkg>, as lowercase hex with no colons or whitespace. This is the
#  same value `apksigner verify --print-certs` reports as "Signer #1
#  certificate SHA-256 digest". Empty string if the package is not
#  installed or PMS does not report it.
#
#  Note: hashing META-INF/<HASH>.RSA inside the APK is unreliable
#  because that PKCS#7 SignedData blob depends on the build environment,
#  not just the signing key. Two APKs signed by the same key in
#  different build farms will hash differently. Asking PMS is the only
#  correct approach on Android.
##############################################################################
installed_cert_sha256() {
    pkg="$1"
    out=$(cmd package dump "$pkg" 2>/dev/null \
            | grep -E 'Signing cert SHA256|Signer #1 cert SHA-256|cert SHA256' \
            | head -1 \
            | sed 's/[^0-9a-fA-F]//g' \
            | tr 'A-F' 'a-f')
    if [ -n "$out" ]; then
        echo "$out"
        return 0
    fi
    out=$(cmd package dump "$pkg" 2>/dev/null \
            | awk '/^[[:space:]]*Signatures:/,/^$/ { print }' \
            | grep -oE '[A-Fa-f0-9]{64}' \
            | head -1 \
            | tr 'A-F' 'a-f')
    [ -n "$out" ] && echo "$out"
}

##############################################################################
#  classify_package_state <pkg>
#
#  Maps PMS visible state onto a six value enum:
#    none                                no copy anywhere
#    system_only_enabled                 system priv-app, enabled for user 0
#    system_only_disabled                system priv-app, disabled for user 0
#    system_with_data_update_enabled     system priv-app plus /data overlay,
#                                        enabled for user 0
#    system_with_data_update_disabled    system priv-app plus /data overlay,
#                                        disabled for user 0
#    data_only                           user installed only, no system copy
#
#  This is the model service.sh uses to decide what runtime remediation
#  each managed package needs. Aurora Services in particular MUST end up
#  as system_only_enabled for its privapp-permissions XML to take effect.
##############################################################################
classify_package_state() {
    pkg="$1"
    dump=$(cmd package dump "$pkg" 2>/dev/null)
    if [ -z "$dump" ] || ! echo "$dump" | grep -q "Package \[$pkg\]"; then
        echo "none"
        return
    fi
    has_system=0
    has_updated=0
    user0_installed=1

    flags_line=$(echo "$dump" | awk '/^[[:space:]]*flags=\[/{print; exit}')
    echo "$flags_line" | grep -q ' SYSTEM '             && has_system=1
    echo "$flags_line" | grep -q ' UPDATED_SYSTEM_APP ' && has_updated=1

    user0_block=$(echo "$dump" | awk '
        /^[[:space:]]*User 0:/ {flag=1; next}
        /^[[:space:]]*User [0-9]+:/ {flag=0}
        flag {print}
    ')
    if echo "$user0_block" | grep -q 'installed=false'; then
        user0_installed=0
    fi

    if [ "$has_system" = 1 ] && [ "$has_updated" = 1 ]; then
        if [ "$user0_installed" = 1 ]; then
            echo "system_with_data_update_enabled"
        else
            echo "system_with_data_update_disabled"
        fi
    elif [ "$has_system" = 1 ]; then
        if [ "$user0_installed" = 1 ]; then
            echo "system_only_enabled"
        else
            echo "system_only_disabled"
        fi
    else
        if [ "$user0_installed" = 1 ]; then
            echo "data_only"
        else
            echo "none"
        fi
    fi
}

##############################################################################
#  remediate_package_runtime <pkg> <expected_cert>
#
#  Called only from service.sh after sys.boot_completed plus the
#  settling delay. Decides whether to act based on the six state
#  classifier and the live cert match. Echoes the action taken.
#
#  Note for Aurora Services specifically: when the user has an
#  F-Droid signed copy installed and we lay down a system priv-app of
#  the same signature, PMS treats it as UPDATED_SYSTEM_APP and strips
#  FLAG_PRIVILEGED for the user visible PackageInfo. We have to drop
#  the data side overlay (with -k to preserve user data) and then
#  install-existing the system copy so privapp permissions take effect.
##############################################################################
remediate_package_runtime() {
    pkg="$1"
    expected_cert="$2"
    state=$(classify_package_state "$pkg")
    case "$state" in
        none|data_only)
            echo "$state"
            return
            ;;
        system_only_enabled)
            echo "$state"
            return
            ;;
        system_only_disabled)
            cmd package install-existing --user 0 "$pkg" >/dev/null 2>&1
            ;;
        system_with_data_update_enabled|system_with_data_update_disabled)
            cmd package uninstall -k --user 0 "$pkg" >/dev/null 2>&1
            sleep 1
            cmd package install-existing --user 0 "$pkg" >/dev/null 2>&1
            ;;
    esac
    classify_package_state "$pkg"
}

##############################################################################
#  load_config: reads /data/adb/dresosmicrog/config and exports per
#  toggle variables. Config file is plain key=value, one per line.
##############################################################################
load_config() {
    DRESOS_DEBLOAT_ENABLE="$DRESOS_DEBLOAT_ENABLE_DEFAULT"
    DRESOS_HARDEN_ENABLE="$DRESOS_HARDEN_ENABLE_DEFAULT"
    DRESOS_WALLPAPER_ENABLE="$DRESOS_WALLPAPER_ENABLE_DEFAULT"
    DRESOS_AURORA_BACKEND="$DRESOS_AURORA_BACKEND_DEFAULT"
    DRESOS_SAFE_INSTALL="$DRESOS_SAFE_INSTALL_DEFAULT"
    cfg="${DRESOS_STATE_DIR}/config"
    if [ -f "$cfg" ]; then
        while IFS='=' read -r k v; do
            k=$(echo "$k" | tr -d ' \t\r')
            v=$(echo "$v" | tr -d ' \t\r')
            case "$k" in
                debloat)        DRESOS_DEBLOAT_ENABLE="$v" ;;
                harden)         DRESOS_HARDEN_ENABLE="$v" ;;
                wallpaper)      DRESOS_WALLPAPER_ENABLE="$v" ;;
                aurora_backend) DRESOS_AURORA_BACKEND="$v" ;;
                safe_install)   DRESOS_SAFE_INSTALL="$v" ;;
            esac
        done < "$cfg"
    fi
}

##############################################################################
#  Bootloop sentinel, heartbeat driven, per component.
#
#  Layout in DRESOS_STATE_DIR:
#    bootloop_count                   global strike counter
#    last_boot_ok_epoch               heartbeat from end of service.sh
#    installed_at_epoch               written at install
#    disable_zygisk                   present if Zygisk hook implicated
#    disable_priv_app                 present if priv-app overlay implicated
#    disable_debloat                  present if debloat list implicated
##############################################################################
bootloop_count() {
    f="${DRESOS_STATE_DIR}/bootloop_count"
    [ -f "$f" ] && cat "$f" || echo 0
}

bootloop_strike() {
    f="${DRESOS_STATE_DIR}/bootloop_count"
    n=$(bootloop_count)
    n=$((n + 1))
    mkdir -p "${DRESOS_STATE_DIR}"
    echo "$n" > "$f"
    echo "$n"
}

bootloop_clear() {
    f="${DRESOS_STATE_DIR}/bootloop_count"
    mkdir -p "${DRESOS_STATE_DIR}"
    echo 0 > "$f"
}

bootloop_heartbeat_ok() {
    install_ts_file="${DRESOS_STATE_DIR}/installed_at_epoch"
    heartbeat_file="${DRESOS_STATE_DIR}/last_boot_ok_epoch"
    [ ! -f "$install_ts_file" ] && return 0
    [ ! -f "$heartbeat_file" ]  && return 1
    install_ts=$(cat "$install_ts_file" 2>/dev/null)
    heartbeat=$(cat "$heartbeat_file" 2>/dev/null)
    [ -z "$install_ts" ] && return 0
    [ -z "$heartbeat" ]  && return 1
    [ "$heartbeat" -ge "$install_ts" ] && return 0
    return 1
}

bootloop_heartbeat_write() {
    mkdir -p "${DRESOS_STATE_DIR}" 2>/dev/null
    date '+%s' > "${DRESOS_STATE_DIR}/last_boot_ok_epoch"
}

stage_marker_set()   { mkdir -p "${DRESOS_STATE_DIR}" 2>/dev/null; touch "${DRESOS_STATE_DIR}/stage.$1"; }
stage_marker_clear() { rm -f "${DRESOS_STATE_DIR}/stage.$1" 2>/dev/null; }
stage_marker_check() { [ -f "${DRESOS_STATE_DIR}/stage.$1" ]; }

##############################################################################
#  apply_hardening_settings
#
#  captive_portal_mode is 1 with the URLs pointed at GrapheneOS's
#  privacy respecting endpoint (the GrapheneOS and CalyxOS baseline).
#  Setting it to 0 would disable captive portal detection entirely and
#  silently break public Wi-Fi at hotels, trains, and airports.
#  private_dns set to dns.quad9.net is opt in via DRESOS_HARDEN_ENABLE
#  because it is known to break some German DB Zugportal style captive
#  portals. Also enables wifi_random_mac and lockdown_in_power_menu.
##############################################################################
apply_hardening_settings() {
    settings put global captive_portal_mode 1                                       >/dev/null 2>&1
    settings put global captive_portal_detection_enabled 1                          >/dev/null 2>&1
    settings put global captive_portal_server connectivitycheck.grapheneos.network  >/dev/null 2>&1
    settings put global captive_portal_https_url \
        https://connectivitycheck.grapheneos.network/generate_204                   >/dev/null 2>&1
    settings put global captive_portal_http_url  \
        http://connectivitycheck.grapheneos.network/generate_204                    >/dev/null 2>&1
    settings put global captive_portal_fallback_url \
        https://connectivitycheck.grapheneos.network/generate_204                   >/dev/null 2>&1
    settings put global captive_portal_other_fallback_urls \
        https://connectivitycheck.grapheneos.network/generate_204                   >/dev/null 2>&1

    settings put global ntp_server time.cloudflare.com                              >/dev/null 2>&1
    settings put global ntp_timeout 30000                                           >/dev/null 2>&1

    settings put global private_dns_mode hostname                                   >/dev/null 2>&1
    settings put global private_dns_specifier dns.quad9.net                         >/dev/null 2>&1

    settings put secure send_action_app_error 0                                     >/dev/null 2>&1
    settings put secure recovery_logging 0                                          >/dev/null 2>&1
    settings put global wifi_scan_always_enabled 0                                  >/dev/null 2>&1
    settings put global bluetooth_scan_always_enabled 0                             >/dev/null 2>&1
    settings put global package_verifier_enable 0                                   >/dev/null 2>&1
    settings put global upload_apk_enable 0                                         >/dev/null 2>&1
    settings put global wifi_random_mac 1                                           >/dev/null 2>&1
    settings put global ble_scan_always_enabled 0                                   >/dev/null 2>&1
    settings put secure lockdown_in_power_menu 1                                    >/dev/null 2>&1
}

revert_hardening_settings() {
    settings put global captive_portal_mode 1                              >/dev/null 2>&1
    settings put global captive_portal_detection_enabled 1                 >/dev/null 2>&1
    settings delete global captive_portal_server                           >/dev/null 2>&1
    settings delete global captive_portal_https_url                        >/dev/null 2>&1
    settings delete global captive_portal_http_url                         >/dev/null 2>&1
    settings delete global captive_portal_fallback_url                     >/dev/null 2>&1
    settings delete global captive_portal_other_fallback_urls              >/dev/null 2>&1
    settings delete global ntp_server                                      >/dev/null 2>&1
    settings delete global ntp_timeout                                     >/dev/null 2>&1
    settings put global private_dns_mode opportunistic                     >/dev/null 2>&1
    settings delete global private_dns_specifier                           >/dev/null 2>&1
    settings delete secure  send_action_app_error                          >/dev/null 2>&1
    settings delete secure  recovery_logging                               >/dev/null 2>&1
    settings put    global  wifi_scan_always_enabled 1                     >/dev/null 2>&1
    settings put    global  bluetooth_scan_always_enabled 1                >/dev/null 2>&1
    settings put    global  package_verifier_enable 1                      >/dev/null 2>&1
    settings delete global  upload_apk_enable                              >/dev/null 2>&1
    settings delete global  ble_scan_always_enabled                        >/dev/null 2>&1
    settings delete secure  lockdown_in_power_menu                         >/dev/null 2>&1
}
