#!/system/bin/sh
##############################################################################
#  DresOS microG  v3.1.0  action.sh   (READ-ONLY diagnostics)
#
#  Tapping Action in the Magisk app runs this. It only READS state and prints
#  a report. It never installs modules, never deletes anything, and never
#  touches other modules. The one file it may show is the watchdog's reason
#  file, if a previous boot tripped it.
##############################################################################
MODDIR=${0%/*}
GP() { getprop "$1" 2>/dev/null; }

FLAVOR="microg-key"; [ -f "$MODDIR/flavor" ] && FLAVOR=$(cat "$MODDIR/flavor" 2>/dev/null)
echo "DresOS microG  v3.1.0  status"
echo "============================="
echo "Device   : $(GP ro.product.manufacturer) $(GP ro.product.model) ($(GP ro.product.device))"
echo "Android  : $(GP ro.build.version.release)  API $(GP ro.build.version.sdk)  ABI $(GP ro.product.cpu.abi)"
echo "ROM      : LineageOS $(GP ro.lineage.build.version)$(GP ro.calyxos.version)$(GP ro.iode.version)$(GP ro.e.version)"
echo "privapp  : ro.control_privapp_permissions=$(GP ro.control_privapp_permissions)"
echo "flavor   : $FLAVOR  ($([ "$FLAVOR" = google-signed ] && echo 'Google-signed, no spoofing needed; do not update microG from F-Droid' || echo 'official microG key; needs ROM spoofing'))"
echo

check_pkg() {
    pkg="$1"; label="$2"
    path=$(pm path "$pkg" 2>/dev/null | head -1 | sed 's/^package://')
    if [ -z "$path" ]; then
        printf "  %-22s NOT INSTALLED\n" "$label"
        return
    fi
    state="enabled"
    pm list packages -d 2>/dev/null | grep -q "^package:$pkg\$" && state="DISABLED"
    printf "  %-22s installed (%s)\n" "$label" "$state"
    printf "  %-22s   %s\n" "" "$path"
}

echo "Packages:"
check_pkg com.google.android.gms     "microG GmsCore"
check_pkg com.android.vending        "microG Companion"
check_pkg com.google.android.gsf     "GsfProxy"
check_pkg com.aurora.store           "Aurora Store"
check_pkg com.aurora.services        "Aurora Services"
echo "  (DroidGuard is built into GmsCore since microG 0.3.x; no separate app.)"
echo

echo "Signature spoofing:"
if pm dump com.google.android.gms 2>/dev/null | grep -qi 'fake_package_signature'; then
    echo "  GmsCore requests FAKE_PACKAGE_SIGNATURE : yes (this is microG)"
else
    echo "  GmsCore requests FAKE_PACKAGE_SIGNATURE : no"
fi
echo "  The definitive check is microG Settings > Self-Check: look for the"
echo "  green 'System spoofs signature' line. If it is red, this ROM has no"
echo "  signature spoofing (typical of stock firmware) and signature-checking"
echo "  apps will not work; use a ROM with microG spoofing support."
echo

echo "Bootloop watchdog:"
if [ -f /data/adb/dresos_microg_disabled_reason ]; then
    echo "  TRIPPED on a previous boot:"
    sed 's/^/    /' /data/adb/dresos_microg_disabled_reason
    echo "  Re-enable the module in the Magisk app once the cause is resolved."
elif [ -f /data/adb/dresos_microg_boot_pending ]; then
    echo "  armed (this boot not yet marked complete)"
else
    echo "  armed and clear (last boot completed normally)"
fi
echo

echo "Coexisting modules (left untouched):"
for d in /data/adb/modules/*/; do
    [ -f "$d/module.prop" ] || continue
    id=$(grep '^id=' "$d/module.prop" | cut -d= -f2)
    [ "$id" = "dresosmicrog" ] && continue
    st="on"; [ -f "$d/disable" ] && st="disabled"
    printf "  %-28s %s\n" "$id" "$st"
done
echo
echo "If microG misbehaves, open microG Settings > Self-Check first."
