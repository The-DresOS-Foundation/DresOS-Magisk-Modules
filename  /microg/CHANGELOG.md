## v3.1.1

### Changed: stock-ROM signature-spoofing guidance

- The installer and README now point stock-ROM users at the mechanism that actually works: signature spoofing. On Android 15 and below, LSPosed (JingMatrix fork) plus FakeGApps. The installer detects the Android version and, on Android 16, states plainly that FakeGApps does not support 16 yet and the services.jar patchers fail on 16, so a ROM with built-in microG spoofing is currently required there for full functionality.
- The module still bundles no spoofing layer of its own, deliberately, since the Zygisk/Xposed layer was the source of earlier boot loops. Spoofing is left to LSPosed/FakeGApps or the ROM.
- The officially signed microG (standard) path, the systemless masking, the regenerated privapp-permissions allowlist and the bootloop watchdog are all unchanged.

## v3.1.0

Adds an optional stock flavor that makes microG work on stock firmware with no signature spoofing at all, by signing the bundled microG with Google's own certificate. The standard flavor (officially signed microG for spoofing-capable ROMs) is unchanged and remains the default.

### Added: stock flavor (Google-signed)

- New make-google-signed.sh transplants Google's signing certificate onto the microG GmsCore, Companion and GsfProxy APKs using apksigcopier, then verifies each output actually carries Google's certificate (SHA-256 f0fd6c5b...). It borrows microG's own APK-signing-block offset before patching, so the output APKs stay their normal size instead of being padded up to the donor's size, which was the known pitfall of the naive approach.
- build-module.sh gains GOOGLE_SIGNED=1, which builds DresOS-microG-v3_1_0-stock.zip from the Google-signed APKs and writes a flavor marker into the module. customize.sh and action.sh read that marker: the stock flavor states plainly that no spoofing is needed and that microG must not be updated from F-Droid in this mode, while the standard flavor keeps its existing spoofing guidance.
- You provide a genuine Google Play Services APK as the signature donor (com.google.android.gms, com.android.vending and com.google.android.gsf share the same Google certificate, so one donor covers all three; per-app donors are also supported).

### How the stock flavor behaves

- Because the copied signature is valid against Google's bytes and not microG's, the Google-signed APKs verify only as system or privileged apps, which is exactly how this module installs them. They cannot be installed as user apps, and microG can no longer be updated from F-Droid: update by flashing a rebuilt module. This is the same trade-off every no-signature-spoofing approach makes, and it is the only way to run microG on stock Android without an Xposed or Zygisk spoofing layer.
- The real-Google-Play-Services masking from v3.0.2 still applies, so the stock flavor can take over the Google package names on stock firmware.
- apksigcopier was archived in May 2025, so a future APK Signature Scheme v4 could require revisiting this path. Confirm on-device via microG Settings, Self-Check that "microG Services has correct signature" is green.

## v3.0.2

Fixes the three problems reported on the XDA thread and GitHub: the stock-Android install abort, the lack of bootloop recovery, and the broken auto-update pipeline. No change to the microG binaries themselves.

### Fixed

- Stock firmware no longer aborts with "Remove Google Play Services / GApps first, then reflash", which asked for something impossible on stock. When real Google Play Services is present the module now masks it systemlessly (an empty-directory .replace marker over the stock GmsCore, Play Store, and Services Framework) so microG can take over those package names. It is fully reversible: removing the module restores the stock Google apps.
- The auto-update pipeline was 404ing on every run because it tried to download the standalone DroidGuard Helper, which microG removed from its repo after integrating DroidGuard into GmsCore. DroidGuard is no longer fetched or bundled. The microG core is now resolved purely by parsing the repo index, so a new upstream versionCode can never 404 the build again, and downloads are validated as real APKs (ZIP magic) so an HTML error page can never be saved as an .apk.
- Aurora Store and Aurora Services are now fetched by index from IzzyOnDroid and are optional: if that repo is briefly unavailable the core microG module still builds.

### Added

- A minimal bootloop watchdog (post-fs-data.sh + service.sh). Each boot raises a flag that is cleared only after the system fully boots; if two boots in a row never complete, the module disables only itself so the device recovers, and writes a reason file the Action button shows. This is the one piece of boot-time code in the module: no Zygisk, no PackageManager work, no changes to other modules. It is the safety net for the clean-LineageOS bootloop class that a post-fs-data-only sentinel could not catch, since a system_server crash happens after post-fs-data completes.
- The privileged-permission allowlist is now regenerated from the actual bundled GmsCore and Companion manifests at build time and merged with the committed baseline, so every permission the APKs request is always allowlisted. This closes the path by which a future microG update that adds a new privileged permission could silently reintroduce a bootloop on ROMs with ro.control_privapp_permissions=enforce.

### Still true, and stated plainly in the installer

- Signature spoofing comes from the ROM. On a ROM with microG spoofing support the suite works fully. On stock Android, which has no signature spoofing, microG installs and runs but apps that verify the Google signature will not work, because this module deliberately ships no Xposed/Zygisk spoofing layer (the layer that bootlooped devices in v2.0.0). The installer now states this directly and points to microG Self-Check to confirm.

## v3.0.1

- Added a weekly GitHub Actions pipeline that pulls the latest officially signed microG core (GmsCore, Companion, GsfProxy) from the official microG F-Droid repo and auto-bumps the module when upstream changes.
- Updated the module description: microG now coexists with the DresOS WebView module (the AOSmium WebView module it previously named has been replaced by DresOS WebView).
- No change to the bundled microG APKs or the install logic. Maintenance and tooling release.

# DresOS microG Changelog

All notable changes to the DresOS microG Magisk module are documented in this file.

## v3.0.0 2026-06-04

A ground-up rebuild of how the module delivers signature spoofing. Earlier releases bundled a signature-spoofing layer inside the module. v3.0.0 removes that entirely and instead relies on the ROM to spoof the officially signed microG, which is the approach modern degoogling ROMs are built around. The result is a pure file overlay that is dramatically simpler and cannot bootloop the device or interfere with other modules.

### What changed

- The module now ships the officially signed microG GmsCore 0.3.15.250932 and Companion 0.3.15.40226 (signing key `9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165`). Because the ROM-side spoofing patch on modern ROMs is keyed to the official microG signature, placing these in priv-app is all that is needed for spoofing to activate on a supported ROM.
- The privileged-permission allowlist is generated directly from the bundled APK manifests, so every privileged permission microG requests is allowlisted. On ROMs with `ro.control_privapp_permissions=enforce` a single missing entry is a guaranteed bootloop, and this closes that gap, including the newer permissions current microG requests.
- The allowlist XML, the sysconfig file, and the default-permissions file all sit on the same partition as the APKs (`product`), satisfying the Android 11 and newer same-partition rule.
- DroidGuard and Aurora Store are placed as ordinary apps under `product/app`, where privileged-permission enforcement does not apply.

### Removed

- The bundled Zygisk signature-spoofing hook (`zygisk/*.so`) and all runtime scripts that came with it (`post-fs-data.sh`, `service.sh`, `constants.sh`, `functions.sh`, `sepolicy.rule`). The module no longer runs any code at boot.
- The runtime PackageManager remediation, the debloat pass, the hardening pass, and the bootloop sentinel. None of them are needed for a pure file overlay, and removing them removes every path by which the module could affect the rest of the system.

### Behaviour on different ROMs

- On ROMs that support microG signature spoofing (LineageOS builds from 2024-02-26 onward, e/OS, CalyxOS, iodeOS, DivestOS and others) the suite works fully, spoofing included, with nothing to toggle.
- On a ROM with no microG spoofing mechanism, microG still installs and runs, but apps that verify the Google signature need a ROM that supports microG. The module intentionally does not bundle an Xposed spoofing layer.

### Notes

- `action.sh` is now a read-only diagnostic that reports package presence, ROM spoofing support, and coexisting modules. It changes nothing.
- The module refuses to install on GrapheneOS and where Google Play Services is already present.


## v2.0.0 2026-05-25 (initial public release)

This is the first public release of the DresOS microG Magisk module. The release ships a fully working systemless microG suite (GmsCore, Companion, GsfProxy, DroidGuard) plus the Aurora Store user app.

**We are putting this out the door now because we are behind on the DresOS roadmap and we rely on community testing to move forward.** If you flash it and something breaks, please file an issue. Bug reports from the community are what unblocks v2.1.0 and v2.2.0.

### What works in v2.0.0

- microG GmsCore, Companion (FakeStore), GsfProxy, and DroidGuard install cleanly as systemless privileged apps on Android 8 through 16, on arm64 and x86_64, on stock OEM Android, AOSP, LineageOS, CalyxOS, iodeOS, /e/OS, DivestOS, OneUI, HyperOS, OxygenOS, ColorOS, RealmeUI, FuntouchOS, NothingOS, and the major Sony, Asus, Motorola, and Fairphone variants.
- Aurora Store installs as a regular user app and works for browsing and downloading apps from Google Play under anonymous login.
- Signature spoofing via the bundled Zygisk hook (arm64-v8a, x86_64) scoped to the microG process only. No LSPosed required on these ABIs.
- Prebaked runtime Google debloat via `pm disable-user`. Reversible by uninstalling the module.
- Runtime security hardening (captive portal pointed at GrapheneOS endpoints, Quad9 private DNS, WiFi MAC randomization, lockdown in power menu, and other defensive settings).
- Per component bootloop sentinel. If any single piece does not survive three boots, only that piece is disabled on the next boot and the rest of the module continues working.
- ROM autodetection. ROMs that already ship upstream signed microG are detected via X.509 cert SHA-256 (`9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165`) and only the Aurora components are staged.

### Known issue

**Aurora Privileged Extension** (`com.aurora.services`) does not install reliably as a system priv app on all devices in v2.0.0. Aurora Store itself works fine. The silent install path through Aurora Services is the affected piece. Users will see the standard Android installer prompt for each Aurora Store install until this is fixed.

A targeted fix is the headline feature of **v2.1.0** (see roadmap below).

### Coming in upcoming releases

**v2.1.0 (Aurora Privileged Extension fix):**
- Rework the Aurora Services staging logic to land as `system_only_enabled` on every supported device.
- Defer all Aurora Services PMS work to a dedicated post boot self heal pass that detects `system_with_data_update_enabled`, `system_with_data_update_disabled`, and `data_only` states and remediates each.
- Match the bundled APK signing identity against the F-Droid build farm certificate SHA-256 (`5c83c7672b929955dc0a1db89a5e6ae4389e2eae7ec939956041694e5815f532`) at runtime to keep signature compatibility with a user installed F-Droid copy.
- Bundle the privileged extension at `/system/product/priv-app/AuroraServicesMG/` with the matching `privapp-permissions` XML in the same partition, per Android 11 plus enforcement.

**v2.2.0 (SafetyNet and Play Integrity Fix):**
- Bundle an integrated Play Integrity Fix module so apps requiring attestation (banking apps, Pokemon Go, some streaming services) pass without a separate module flash.
- Ship the device fingerprint spoof pinned to a known Play Integrity passing profile.
- Integrate with DroidGuard Helper so SafetyNet self check inside microG goes green.
- Document the trade offs in the README (attestation spoofing is detectable in principle by hardware backed attestation on Android 13 plus on Pixel and recent Samsung devices).

**Beyond v2.2.0:**
- arm and x86 prebuilt Zygisk objects so the bundled spoof works on every ABI without LSPosed.
- Optional removal of Aurora Services from the default install (the Aurora team upstreamed Shizuku based silent installs in 4.4 and deprecated the privileged extension in October 2023).
- An action.sh option to switch the Aurora Store backend between Google's Play servers and the F-Droid alternative.

### Help us out

We are a small team. If you flash this and something does not work, please open a bug report at https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/issues with:

- Device model and Android version (`getprop ro.product.model`, `getprop ro.build.version.release`)
- ROM (stock OEM, CalyxOS, LineageOS, etc.) and ROM version
- Root provider and version (Magisk v30.7, KernelSU, APatch)
- Zygisk provider (built in Magisk, ZygiskNext, ReZygisk)
- Output of the Action button on the module in the Magisk app
- The three logs at `/data/adb/modules/dresosmicrog/logs/`

### Architectural notes

- **Same partition staging.** APKs and matching `privapp-permissions` XML land in the same partition (`system/product/priv-app` on API 28 plus, `system/priv-app` on API 26 and 27). Android 11 plus enforces this.
- **Cert verified self heal.** Identity is verified post boot via `cmd package dump` reading the X.509 cert SHA-256 that PMS itself computes, not by hashing META-INF/*.RSA blobs inside the APK at flash time.
- **No directory level .replace markers.** Debloat runs at runtime via `pm disable-user`, avoiding the boot loop on Android 14 plus when an overlay hides a priv-app's ART OAT cache.
- **Per component bootloop sentinel.** Disables only the broken component (Zygisk, priv-app overlay, or debloat) on third strike rather than the entire module.
- **All PMS mutations post boot.** customize.sh does file work only. `pm` and `cmd package` calls happen in service.sh after `sys.boot_completed` plus a settle delay.

### Compatibility

- Android 8.0 (API 26) through Android 16 (API 36)
- arm64-v8a and x86_64 (full signature spoofing); armeabi-v7a, armeabi, x86, and riscv64 install cleanly but need FakeGApps under LSPosed for spoofing in v2.0.0
- Magisk 24.0+ with Zygisk enabled
- KernelSU with ZygiskNext or ReZygisk
- APatch with ZygiskNext or ReZygisk
