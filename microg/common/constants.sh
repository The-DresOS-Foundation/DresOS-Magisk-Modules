#!/system/bin/sh
##############################################################################
#  DresOS microG: common/constants.sh
#
#  Single source of truth for module identity, known signing cert
#  fingerprints, managed package lists, bloat package catalogue, and
#  runtime tuning. POSIX sh only, no bashisms, busybox compatible.
##############################################################################

##############################################################################
#  Module identity
##############################################################################
DRESOS_MODID="dresosmicrog"
DRESOS_STATE_DIR="/data/adb/${DRESOS_MODID}"
DRESOS_LOG_DIR_REL="logs"

##############################################################################
#  Known X.509 signing cert SHA 256 fingerprints (lowercase hex, no colons).
#
#  These are the values reported by `cmd package dump <pkg>` on a fully
#  booted device, which is what we compare against post boot. They are
#  the SHA 256 of the X.509 certificate's DER encoding, which is what
#  PackageManager itself computes and what `apksigner verify
#  --print-certs` reports as "Signer #N certificate SHA-256 digest". This
#  is NOT the SHA 256 of META-INF/<HASH>.RSA, which varies between build
#  environments even for APKs signed by the same key.
##############################################################################

##  microG main suite (GmsCore, Companion FakeStore, GsfProxy).
##  microG team key, DN: O=NOGAPPS Project, C=DE. Never rotated.
MICROG_UPSTREAM_CERT="9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165"

##  microG DroidGuard Helper. Different key from the main suite.
MICROG_DROIDGUARD_CERT="862ed9f13a3981432bf86fe93d14596b381d75be83a1d616e2d44a12654ad015"

##  Aurora Store and Aurora Services as built by the F-Droid build farm.
##  Both packages share the F-Droid project key. Bundled APKs MUST be the
##  F-Droid signed builds so any future user side update from F-Droid is
##  signature compatible with the system priv-app copy.
AURORA_FDROID_CERT="5c83c7672b929955dc0a1db89a5e6ae4389e2eae7ec939956041694e5815f532"

##  Real Google Play Services release cert. We never expect to see this on
##  the device's microG slot. If we do, ROM is Google Play certified and
##  installing microG over it is a user error we still handle.
GOOGLE_GMS_RELEASE_CERT="f0fd6c5b410f25cb25c3b53346c8972fae30f8ee7411df910480ad6b2d60db83"

##############################################################################
#  Packages this module owns.
##############################################################################
MANAGED_GOOGLE_PKGS="com.google.android.gms com.android.vending com.google.android.gsf"
MANAGED_MICROG_PKGS="org.microg.gms.droidguard"
MANAGED_AURORA_PKGS="com.aurora.store com.aurora.services"
MANAGED_ALL_PKGS="${MANAGED_GOOGLE_PKGS} ${MANAGED_MICROG_PKGS} ${MANAGED_AURORA_PKGS}"

##  Per-package staging table: package_name|module_apk|priv_app_dirname|cert
##  Used by customize.sh to stage and by service.sh to verify post boot.
##  Space separated tuples, pipe separated fields. POSIX sh has no arrays.
DRESOS_STAGING_TABLE="
com.google.android.gms|GmsCore.apk|GmsCoreMG|${MICROG_UPSTREAM_CERT}
com.android.vending|Companion.apk|CompanionMG|${MICROG_UPSTREAM_CERT}
com.google.android.gsf|GsfProxy.apk|GsfProxyMG|${MICROG_UPSTREAM_CERT}
org.microg.gms.droidguard|DroidGuard.apk|DroidGuardMG|${MICROG_DROIDGUARD_CERT}
com.aurora.store|AuroraStore.apk|AuroraStoreMG|${AURORA_FDROID_CERT}
com.aurora.services|AuroraServices.apk|AuroraServicesMG|${AURORA_FDROID_CERT}
"

##############################################################################
#  Debloat catalogue. Each entry is a package name. These are disabled at
#  runtime via `pm disable-user --user 0 <pkg>` from service.sh rather
#  than overlaying their priv-app directories with .replace. On Android
#  14 plus a directory level .replace hides the ART OAT cache at
#  <priv_app_dir>/oat/ and the device misses boot complete. Runtime
#  disable is reversible by `pm enable` and survives reboots because it
#  is persisted in /data/system/users/0/package-restrictions.xml.
##############################################################################
DRESOS_DEBLOAT_PKGS="
com.google.android.googlequicksearchbox
com.google.android.apps.maps
com.google.android.apps.photos
com.google.android.youtube
com.google.android.apps.youtube.music
com.google.android.gm
com.google.android.apps.docs
com.google.android.apps.docs.editors.docs
com.google.android.apps.docs.editors.sheets
com.google.android.apps.docs.editors.slides
com.google.android.apps.tachyon
com.google.android.apps.meetings
com.google.android.keep
com.google.android.calendar
com.google.android.deskclock
com.google.android.apps.messaging
com.google.android.dialer
com.google.android.apps.wellbeing
com.google.android.apps.recorder
com.google.android.apps.subscriptions.red
com.google.android.feedback
com.google.android.partnersetup
com.google.android.setupwizard
com.google.android.tts
com.google.android.gms.location.history
com.google.android.apps.turbo
com.google.android.projection.gearhead
com.google.android.printservice.recommendation
com.google.android.apps.restore
com.google.android.gsf.login
com.google.android.onetimeinitializer
com.google.android.syncadapters.contacts
com.google.android.syncadapters.calendar
com.google.android.apps.wallpaper
com.google.android.apps.nbu.files
com.google.android.calculator
com.google.android.apps.cloudprint
com.google.android.apps.gcs
com.google.android.apps.youtube.kids
com.google.android.googlecamera
"

##############################################################################
#  Hardening / debloat configuration defaults.
##############################################################################
DRESOS_DEBLOAT_ENABLE_DEFAULT=0
DRESOS_HARDEN_ENABLE_DEFAULT=1
DRESOS_WALLPAPER_ENABLE_DEFAULT=1
DRESOS_AURORA_BACKEND_DEFAULT="beacondb"
DRESOS_SAFE_INSTALL_DEFAULT=0

##############################################################################
#  Bootloop sentinel threshold. Three consecutive boots that fail to
#  reach service.sh end of run before this counter trips and the module
#  self disables.
##############################################################################
DRESOS_BOOTLOOP_THRESHOLD=3
