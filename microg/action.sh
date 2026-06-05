#!/system/bin/sh
##############################################################################
#  DresOS microG  v3.0.0  action.sh   (READ-ONLY diagnostics)
#
#  Tapping Action in the Magisk app runs this. It only READS state and
#  prints a report. It never installs modules, never writes disable/remove
#  files, never deletes anything, never touches other modules. Safe to run
#  any time.
##############################################################################
MODDIR=${0%/*}
GP() { getprop "$1" 2>/dev/null; }
OFFICIAL="9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165"

echo "DresOS microG  v3.0.0  status"
echo "============================="
echo "Device   : $(GP ro.product.manufacturer) $(GP ro.product.model) ($(GP ro.product.device))"
echo "Android  : $(GP ro.build.version.release)  API $(GP ro.build.version.sdk)  ABI $(GP ro.product.cpu.abi)"
echo "ROM      : LineageOS $(GP ro.lineage.build.version)$(GP ro.calyxos.version)$(GP ro.iode.version)$(GP ro.e.version)"
echo "privapp  : ro.control_privapp_permissions=$(GP ro.control_privapp_permissions)"
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
check_pkg org.microg.gms.droidguard  "DroidGuard"
check_pkg com.aurora.store           "Aurora Store"
check_pkg com.aurora.services        "Aurora Services"
echo

echo "Signature spoofing:"
SPOOF_PERM=$(pm list permissions 2>/dev/null | grep -i fake_package_signature)
if [ -n "$SPOOF_PERM" ]; then
    echo "  ROM defines FAKE_PACKAGE_SIGNATURE : yes"
else
    echo "  ROM defines FAKE_PACKAGE_SIGNATURE : no (ROM has no spoofing support)"
fi
echo "  Definitive check is microG Settings > Self-Check (open it and look"
echo "  for the green 'System spoofs signature' line). Third-party spoof"
echo "  checkers report wrong results on microG-keyed ROMs, so ignore them."
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
echo "Logs: this module ships no boot scripts, so there is nothing to log."
echo "If microG misbehaves, use microG Settings > Self-Check first."
