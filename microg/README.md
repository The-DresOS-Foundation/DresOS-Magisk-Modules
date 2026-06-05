# DresOS microG

A universal, systemless Magisk module that installs the officially signed
microG suite as privileged system apps, so that any ROM which supports
microG signature spoofing will spoof it automatically. It is a pure file
overlay: there is no Zygisk payload, no Xposed framework, no boot script
that changes PackageManager, and it never touches any other Magisk module.
That design is what makes it bootloop-safe and what lets it coexist with
the DresOS AOSmium WebView module without disabling it.

## What is inside

- microG GmsCore 0.3.15.250932 (official, key 9bd06727...)
- microG Companion 0.3.15.40226 (official)
- GsfProxy (official microG key)
- Aurora Store 4.8.3
- Aurora Services
- DroidGuard Helper

GmsCore, Companion and GsfProxy sit in product/priv-app with a complete
privileged-permission allowlist generated directly from their manifests.
Aurora Services sits in product/priv-app with its own single-permission
allowlist. Aurora Store and DroidGuard sit in product/app as ordinary
apps, where privileged-permission enforcement does not apply.

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

## Install

1. Make sure the ROM is degoogled (no Google Play Services present).
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

Remove the module in the Magisk app and reboot. Because the module only
ever overlaid files and never modified real system packages or other
modules, removal is clean.

## Compatibility

- Any Android 8.0 through 16 device with Magisk 24 or newer.
- arm64-v8a, armeabi-v7a, x86_64, x86 (the microG APK is multi-ABI).
- Coexists with the DresOS AOSmium WebView module.
- Refuses to install on GrapheneOS or where Google Play Services exists.

## Credits

- microG Project, microg.org
- Aurora OSS, Aurora Store and Aurora Services
- topjohnwu, Magisk
- nift4 microG Installer Revived, for the privileged-permission reference
