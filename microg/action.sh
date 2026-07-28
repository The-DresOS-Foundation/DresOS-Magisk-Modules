#!/system/bin/sh
MODDIR=${0%/*}
GP() { getprop "$1" 2>/dev/null; }

VER=$(grep '^version=' "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)
echo "DresOS microG  ${VER}  status"
echo "============================="
echo "Device   : $(GP ro.product.manufacturer) $(GP ro.product.model) ($(GP ro.product.device))"
echo "Android  : $(GP ro.build.version.release)  API $(GP ro.build.version.sdk)  ABI $(GP ro.product.cpu.abi)"
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
check_pkg com.aurora.store           "Aurora Store"
check_pkg com.aurora.services        "Aurora Services"
echo

echo "Signature spoofing:"
if pm dump com.google.android.gms 2>/dev/null | grep -qi 'fake_package_signature'; then
    echo "  FAKE_PACKAGE_SIGNATURE requested : yes"
else
    echo "  FAKE_PACKAGE_SIGNATURE requested : no"
fi
echo

echo "Bootloop watchdog:"
if [ -f /data/adb/dresos_microg_disabled_reason ]; then
    echo "  tripped on a previous boot:"
    sed 's/^/    /' /data/adb/dresos_microg_disabled_reason
elif [ -f /data/adb/dresos_microg_boot_pending ]; then
    echo "  armed (this boot not yet marked complete)"
else
    echo "  armed and clear (last boot completed normally)"
fi
echo

echo "Coexisting modules:"
for d in /data/adb/modules/*/; do
    [ -f "$d/module.prop" ] || continue
    id=$(grep '^id=' "$d/module.prop" | cut -d= -f2)
    [ "$id" = "dresosmicrog" ] && continue
    st="on"; [ -f "$d/disable" ] && st="disabled"
    printf "  %-28s %s\n" "$id" "$st"
done
