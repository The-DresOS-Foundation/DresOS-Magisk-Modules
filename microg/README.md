# DresOS microG

A universal, systemless Magisk module that installs the officially signed
microG suite as privileged system apps, so that any ROM which supports
microG signature spoofing will spoof it automatically. There is no Zygisk
payload and no Xposed framework, and it never touches any other Magisk
module, so it coexists with the DresOS WebView module without disabling it.
The only boot-time code is a small bootloop watchdog that disables this
module alone if a boot never completes, so a bad ROM recovers on its own
rather than looping. If real Google Play Services is present, the module
masks it systemlessly (reversibly) so microG can take over its package
names, which is what lets it install on stock firmware.

## What is inside

- microG GmsCore 0.3.15 (official, key 9bd06727...)
- microG Companion (official)
- GsfProxy (official microG key)
- Aurora Store (optional, when available)
- Aurora Services (optional, when available)

DroidGuard is no longer a separate app: microG integrated it into GmsCore
and removed the standalone helper from its repo.

GmsCore, Companion and GsfProxy sit in product/priv-app with a
privileged-permission allowlist that is regenerated from their actual
manifests at build time, so every permission they request is always
allowlisted and a microG update can never reintroduce a permission-mismatch
bootloop. Aurora Services, when included, sits in product/priv-app with its
own single-permission allowlist; Aurora Store sits in product/app.

## How signature spoofing works here

Modern ROMs based on LineageOS spoof the Google signature only for the
officially signed microG, identified by its signing key. Because the
bundled GmsCore and Companion carry that official key and are placed in
priv-app with FAKE_PACKAGE_SIGNATURE allowlisted, a spoofing-capable ROM
activates spoofing on its own. There is nothing to toggle.

ROMs known to support this out of the box include LineageOS builds from
2024-02-26 onward, e/OS, CalyxOS, iodeOS, DivestOS, and several others.
On a ROM with no microG spoofing mechanism at all, microG still installs
and runs, but apps that verify the Google signature will not work until
you move to a ROM that supports microG. This module intentionally does
not bundle an Xposed or LSPosed spoofing layer, because that layer is the
source of the boot loops on recent Android versions.

On stock firmware specifically, microG installs and the stock Google apps
are masked so microG owns the package names, but because stock Android has
no signature spoofing, apps that verify the Google signature will not work
until you move to a ROM with microG spoofing support. The installer states
this plainly and the microG Self-Check confirms it (the "System spoofs
signature" line will be red on such ROMs).

## Two flavors: standard and stock

This module builds in two flavors. You flash whichever fits your device.

Standard (officially signed microG) is the default and is meant for ROMs that
support microG signature spoofing. microG keeps its real signature, so it can
be updated from F-Droid, and the ROM spoofs the Google signature for it. This
is the flavor the auto-update pipeline publishes.

Stock (Google-signed) is for stock firmware and for any ROM where you would
rather not rely on spoofing. The bundled microG GmsCore, Companion and
GsfProxy are signed with Google's own certificate using apksigcopier, so the
system reports them as Google-signed and no signature spoofing is needed
anywhere. The trade-off is inherent to this technique: the copied signature is
valid against Google's bytes, not microG's, so these APKs work only as system
apps (they cannot be installed as user apps), and microG can no longer be
updated from F-Droid. You update by flashing a rebuilt module.

Building the stock flavor (you supply a genuine Google Play Services APK as the
signature donor):

```
cd microg
bash refresh-upstream.sh                       # fetch the microG core APKs
mkdir -p donors && cp /path/to/PlayServices.apk donors/donor.apk
bash make-google-signed.sh                     # transplant Google's signature
GOOGLE_SIGNED=1 bash build-module.sh           # -> DresOS-microG-vX_Y_Z-stock.zip
```

com.google.android.gms, com.android.vending and com.google.android.gsf share
the same Google certificate, so one Play Services donor covers all three. The
build verifies every output actually carries Google's certificate before it
will package the zip.

## Install

1. A degoogled ROM is ideal. If Google Play Services is present, the
   module masks it for you (reversibly); you do not have to remove it by
   hand. On stock firmware without signature spoofing, see the note below.
2. In the Magisk app: Modules, Install from storage, pick the zip.
3. Reboot. The first boot can take a few minutes while PackageManager
   scans GmsCore. Do not force a reboot during it.
4. Open microG Settings, Self-Check. On a spoofing-capable ROM the core
   lines turn green. The definitive spoofing check is this Self-Check
   page, not third-party signature checkers.
5. In Aurora Store, Settings, Installer, choose Aurora Services for
   silent installs, and log in anonymously.

## Diagnostics

Tap Action on the module in the Magisk app for a read-only status report
(package presence, ROM spoofing support, coexisting modules). It changes
nothing.

## Uninstall

Remove the module in the Magisk app and reboot. The module only overlaid
files and masked the Google packages with reversible markers, so removal is
clean and any masked stock Google apps come back.

## Compatibility

- Any Android 8.0 through 16 device with Magisk 24 or newer.
- arm64-v8a, armeabi-v7a, x86_64, x86 (the microG APK is multi-ABI).
- Coexists with the DresOS AOSmium WebView module.
- Refuses to install on GrapheneOS. Where Google Play Services exists it
  masks it rather than refusing.

## Credits

- microG Project, microg.org
- Aurora OSS, Aurora Store and Aurora Services
- topjohnwu, Magisk
- nift4 microG Installer Revived and ale5000 microg-unofficial-installer,
  for the privileged-permission and allowlist-generation references
