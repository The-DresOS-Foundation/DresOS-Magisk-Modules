This folder holds the application APKs that build-module.sh packs into the
flashable zip. You normally do NOT place them by hand: run ../refresh-upstream.sh
first and it fetches the current versions automatically.

Core microG trio (required, officially signed with the microG key):

  GmsCore.apk         microG Services  (com.google.android.gms)
  Companion.apk       microG Companion (com.android.vending)
  GsfProxy.apk        microG GsfProxy  (com.google.android.gsf)

Optional extras (included only if present):

  AuroraStore.apk     Aurora Store     (com.aurora.store)
  AuroraServices.apk  Aurora Services  (com.aurora.services)

DroidGuard is no longer a separate APK: upstream folded it into GmsCore, so
there is nothing extra to place for SafetyNet/Play Integrity attestation.

These APKs are large (GmsCore alone exceeds 100 MB), so they are tracked with
Git LFS (see ../.gitattributes) rather than stored inline; the flashable zip is
also published as a GitHub Release asset. build-module.sh verifies the core trio
carries the official microG key before it will build.

microG on stock firmware: these APKs keep the official microG key, so the system
reports the real microG signature. On a stock ROM, enable signature spoofing with
LSPosed (JingMatrix fork) plus FakeGApps on Android 15 and below; on Android 16
use a ROM with built-in microG spoofing for now. See the module README for the
full setup. The earlier Google-signed stock flavor was removed in v3.1.1 because
a grafted Google signature cannot verify against microG's different bytes.
