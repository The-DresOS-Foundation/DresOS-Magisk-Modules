# DresOS microG

Systemless microG suite for any Android device, any ROM, any architecture, with bundled signature spoofing, runtime Google debloat, security hardening, and per component bootloop protection. Part of the DresOS Defensive Security System.

- Project site: https://dresoperatingsystems.github.io
- XDA support thread: https://xdaforums.com/t/dresos-the-android-defensive-security-system.4787891
- Issue tracker: https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/issues

## What this module does

It installs the microG suite as systemless privileged apps:

- **microG GmsCore** (com.google.android.gms) 0.3.7.250932
- **microG Companion** (com.android.vending), the FakeStore stub
- **microG GsfProxy** (com.google.android.gsf)
- **microG DroidGuard Helper** (org.microg.gms.droidguard)
- **Aurora Store** (com.aurora.store) as a regular user app

After flashing, your degoogled or stock Android device runs apps that depend on Google Play Services without Google's proprietary code or servers.

It spoofs the package signature that microG sees for itself, which microG requires to act as a Play Services replacement, using a bundled Zygisk hook scoped to the microG process only. No Xposed framework, no LSPosed, no separate signature spoofing module is needed on arm64 or x86_64.

It neutralises the stock Google stack on ROMs that ship it, at runtime via `pm disable-user`, not via systemless overlay markers. Removing this module re enables every disabled package automatically.

It detects ROMs that already ship a working upstream signed microG (CalyxOS, LineageOS for microG, iodeOS, /e/OS) by comparing the installed X.509 certificate SHA-256 against the upstream microG fingerprint, and leaves the ROM's copy in place. Only the Aurora components are staged on those ROMs.

It protects against bootloops with a per component sentinel: if any single piece (Zygisk hook, priv-app overlay, debloat pass) does not survive three boots, that piece is disabled on the next boot and the rest of the module keeps working.

## What this module does not do yet

**Aurora Privileged Extension is not reliable in v2.0.0.** Aurora Store itself works fine. The silent install path through `com.aurora.services` does not always land as a system priv app, which means you will be prompted to confirm each app install through the standard Android installer UI. This is fixed in v2.1.0 (see CHANGELOG).

**SafetyNet and Play Integrity will not pass.** Apps that require attestation (most banking apps, Pokemon Go, some streaming services) will fail. v2.2.0 will add a built in Play Integrity Fix so a separate module is not needed.

**Bundled Zygisk spoofer ships arm64-v8a and x86_64 only.** On armeabi-v7a, armeabi, x86, or riscv64, the module installs cleanly without the Zygisk hook. On those ABIs, install FakeGApps under LSPosed (JingMatrix fork) for signature spoofing.

## Requirements

- Magisk 24.0 or newer with Zygisk enabled, or KernelSU or APatch with ZygiskNext or ReZygisk installed.
- Android 8.0 (API 26) or newer. Tested through Android 16 (API 36).
- arm64-v8a or x86_64 for the bundled Zygisk spoof. Any ABI works without it.
- Approximately 280 MB free in /data for the bundled APKs at install time. The mounted footprint is much smaller.

## Install

1. Download `DresOS-microG-v2_0_0.zip` from the Releases page.
2. Flash the zip in the Magisk app, KernelSU app, or APatch app.
3. Reboot.
4. Open microG Settings and run Self Check. Every item should be ticked except SafetyNet (intentionally not in v2.0.0, coming in v2.2.0).
5. If runtime permissions are not granted, press the Action button on this module entry in the Magisk app.
6. Open Aurora Store. Sign in with Anonymous (no Google account). Install apps; you will see the standard Android installer prompt for each one until v2.1.0 lands.

## On ROMs that already ship microG

LineageOS for microG, CalyxOS, iodeOS, /e/OS, and similar already provide native signature spoofing and may ship microG built in. The installer detects upstream signed microG by reading the X.509 certificate SHA-256 via `cmd package dump` after boot, and leaves the ROM's microG in place. The bundled Zygisk hook is removed at install time so there is no double spoof, and only the Aurora components are staged.

GrapheneOS deliberately blocks native signature spoofing and ships its own sandboxed Play Services for compatibility. This module is not designed for GrapheneOS and will abort on it.

## Bootloop recovery

If a single component (Zygisk hook, priv-app overlay, or debloat) fails to boot three times in a row, the sentinel writes a disable flag for that component only and the module continues running with the broken piece skipped. The Action button reports which component is disabled.

To recover manually, boot holding volume down to enter Magisk safe mode (disables all modules), then re enable the ones you trust. From recovery you can also delete `/data/adb/modules/dresosmicrog` to fully remove the module.

## Logs and diagnostics

- `/data/adb/modules/dresosmicrog/logs/install.log`
- `/data/adb/modules/dresosmicrog/logs/boot.log`
- `/data/adb/modules/dresosmicrog/logs/service.log`
- `/data/adb/dresosmicrog/` (runtime state, including decision records and bootloop counters)

The Action button on the module reprints the full status dashboard, regrants runtime permissions to GmsCore, Companion, GSF, and DroidGuard, and restarts the microG components.

## Reporting bugs

We are a small team and we are putting v2.0.0 out the door because we are behind schedule on the DresOS roadmap. **We rely on community testing and bug reports to make progress on v2.1.0 and v2.2.0.**

Please open an issue at https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/issues with:

- Device model: `getprop ro.product.model`
- Android version: `getprop ro.build.version.release`
- API level: `getprop ro.build.version.sdk`
- ROM and ROM version (stock OEM, CalyxOS, LineageOS, etc.)
- Root provider and version (Magisk v30.7, KernelSU, APatch)
- Zygisk provider (built in Magisk, ZygiskNext, ReZygisk)
- Output of the Action button on the module in the Magisk app
- The three log files attached

## Credits

- microG project (https://microg.org)
- Aurora OSS (https://auroraoss.com)
- LSPlant inline hook engine (LSPosed project)
- Dobby native hook library
- NanoDroid (Christopher Roy Bratusek) as a long running reference implementation
- noogle-magisk (SelfRef) as architectural reference

## License

GPL-3.0-or-later.

The bundled microG and Aurora APKs are redistributed unmodified under their upstream licenses (microG project, Aurora OSS). The bundled `google.cer` is the public Android platform test certificate used industry wide for microG signature spoofing.
