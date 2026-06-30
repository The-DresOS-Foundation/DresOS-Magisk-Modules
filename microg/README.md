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

## Stock ROMs: adding signature spoofing

There is one flavor: the officially signed microG described above. On a ROM that
already spoofs the microG signature (the list above), it just works. On a stock
ROM or a plain LineageOS build that does not spoof, microG installs and masks the
Google apps, but signature-checking apps stay broken until you add spoofing.

On Android 15 and below, add it with LSPosed and FakeGApps:

1. Enable Zygisk in Magisk settings.
2. Install LSPosed (the JingMatrix fork, which covers Android 8.1 through 16) as a
   Magisk module and reboot.
3. Install the FakeGApps APK, open LSPosed, enable FakeGApps, and reboot.
4. In microG Settings, Self-Check, confirm "System spoofs signature" is green.

On Android 16 this path does not work yet: FakeGApps currently caps at Android 15,
and the services.jar patchers (Haruka, Haystack, NanoDroid) fail on 16. Until that
lands, the only way to get full microG on stock Android 16 is a ROM with built-in
microG spoofing (LineageOS for microG, e/OS, CalyxOS, iodeOS, DivestOS).

This module deliberately bundles no spoofing layer of its own: an earlier version
did and it boot-looped devices, so spoofing is left to LSPosed/FakeGApps or the
ROM, where it is maintained and far safer.

A previous build shipped a "Google-signed" stock flavor that grafted Google's
certificate onto microG with apksigcopier. It was removed in v3.1.1: a signature
copied from Google's APK does not verify against microG's different bytes (doing
that needs Google's private key, which only Google holds), so it failed to install
on modern Android. Signature spoofing is the correct mechanism, and it is the one
described above.

## Install

1. A degoogled ROM is ideal. If Google Play Services is present, the
   module masks it for you (reversibly); you do not have to remove it by
   hand. On a stock ROM without signature spoofing, see "Stock ROMs: adding
   signature spoofing" above.
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
