Place the officially signed APKs here before running ../build-module.sh:

  GmsCore.apk         microG Services (com.google.android.gms), official microG key
  Companion.apk       microG Companion (com.android.vending), official microG key
  GsfProxy.apk        microG GsfProxy (com.google.android.gsf), official microG key
  AuroraStore.apk     Aurora Store (com.aurora.store)
  AuroraServices.apk  Aurora Services (com.aurora.services)
  DroidGuard.apk      DroidGuard Helper (org.microg.gms.droidguard)

These are intentionally NOT committed to git: GmsCore alone exceeds GitHub's
100 MB per-file limit. The flashable zip is published as a GitHub Release asset.
build-module.sh verifies the microG core APKs carry the official signing key
before it will build.
