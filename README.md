# DresOS Magisk Modules

Part of the [DresOS Android Defensive Security System](https://github.com/DresOperatingSystems/DresOS-The-Android-Defensive-Security-System).

[![Please Help fund future projects and keep this one going](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dresos)

> **Help fund the next module.** DresOS is built by a small open source team in our spare time. If our guide saves you a weekend of research, tip the jar at [ko-fi.com/dresos](https://ko-fi.com/dresos). Funds go to test devices, hosting, and developer time on the next Magisk module.

---

## Modules

### WebView (`dresoswv`)

Replaces Android System WebView with [AOSmium](https://axpos.org/), a Chromium fork hardened with GrapheneOS and Vanadium security patches.

[Download latest release](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/download/webview-v2.2.0/DresOS-WebView-v2_2_0.zip)

|  |  |
| --- | --- |
| AOSmium version | 147.0.7727.49 |
| Package | `org.axpos.aosmium_wv` |
| Android | 10 through 16+ (API 29 to 36+) |
| ABI | arm, arm64 |
| Root | Magisk 24.0+ |

See [aosmium-webview/README.md](aosmium-webview/README.md) for details.

### microG (`dresosmicrog`)

Universal systemless microG suite and drop-in replacement for Google Play Services. Ships the officially signed microG GmsCore, Companion (FakeStore) and GsfProxy as privileged system apps, plus Aurora Store, Aurora Services and DroidGuard Helper. It is a pure file overlay with no Zygisk payload, no Xposed, and no boot scripts, so it cannot bootloop the device and coexists cleanly with the AOSmium WebView module. Signature spoofing is provided by the ROM: because the microG APKs carry the official microG key, any ROM that supports microG signature spoofing activates it automatically.

[Download latest release](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/download/microg-v3.0.1/DresOS-microG-v3_0_1.zip)

|  |  |
| --- | --- |
| microG GmsCore | 0.3.15.250932 |
| Packages | `com.google.android.gms`, `com.android.vending`, `com.google.android.gsf`, `org.microg.gms.droidguard`, `com.aurora.store`, `com.aurora.services` |
| Android | 8.0 through 16+ (API 26 to 36+) |
| ABI | arm, arm64, x86, x86_64 (multi-ABI microG APK) |
| Signature spoofing | provided by the ROM for officially signed microG (LineageOS 2024-02-26+, e/OS, CalyxOS, iodeOS, DivestOS, and others) |
| Root | Magisk 24.0+ |

See [microg/README.md](microg/README.md) for details.

## Roadmap

| Module | Status |
| --- | --- |
| `dresoswv` AOSmium WebView | v2.2.0 |
| `dresosmicrog` microG | v3.0.0 |
| `dresosdebloat` Debloater | Planned |
| `dresosperms` Permissions Hardener | Planned |
| `dresosafwall` AFWall+ Bootstrap | Planned |

## License

GPL-3.0.

## Links

- https://dresoperatingsystems.github.io
- https://xdaforums.com/t/dresos-the-android-defensive-security-system.4787891
