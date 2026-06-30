This folder holds the application APKs that build-module.sh packs into the
flashable zip. You normally do NOT place them by hand: 
Core microG trio (required, officially signed with the microG key):

  GmsCore.apk         microG Services  (com.google.android.gms)
  Companion.apk       microG Companion (com.android.vending)
  GsfProxy.apk        microG GsfProxy  (com.google.android.gsf)

Optional extras (included only if present):

  AuroraStore.apk     Aurora Store     (com.aurora.store)
  AuroraServices.apk  Aurora Services  (com.aurora.services)

DroidGuard is no longer a separate APK: upstream folded it into GmsCore, so
there is nothing extra to place for SafetyNet/Play Integrity attestation.

These APKs are intentionally NOT committed to git: GmsCore alone exceeds
GitHub's 100 MB per-file limit. The flashable zip is published as a GitHub
Release asset. build-module.sh verifies the core trio carries the official
microG key before it will build.

STOCK FLAVOR (optional): to build microG signed with Google's certificate so it
works on stock firmware with no signature spoofing, place a genuine Google Play
Services APK at ../donors/donor.apk (or pass it to ../make-google-signed.sh),
run ../make-google-signed.sh to produce ../apk-google-signed/, then build with
GOOGLE_SIGNED=1 ../build-module.sh. Per-app donors donors/gms.apk,
donors/vending.apk and donors/gsf.apk override the shared donor if present.
The donor is large and proprietary, so it is never committed either.
