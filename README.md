# DresOS Magisk Modules

Part of the [DresOS Android Defensive Security System](https://github.com/DresOperatingSystems/DresOS-The-Android-Defensive-Security-System).

[![Please Help fund future projects and keep this one going](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dresos)

> **Help fund the next module.** DresOS is built by a small open source team in our spare time. If our guide saves you a weekend of research, tip the jar at [ko-fi.com/dresos](https://ko-fi.com/dresos). Funds go to test devices, hosting, and developer time on the next Magisk module.

---

## Modules

### AOSmium WebView (`dresoswv`)

Replaces Android System WebView with [AOSmium](https://axpos.org/), a Chromium fork hardened with GrapheneOS and Vanadium security patches.

[Download latest release](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/download/aosmium-webview-v2.2.0/DresOS-AOSmium-WebView-v2_2_0.zip)

|  |  |
| --- | --- |
| AOSmium version | 147.0.7727.49 |
| Package | `org.axpos.aosmium_wv` |
| Android | 10 through 16+ (API 29 to 36+) |
| ABI | arm, arm64 |
| Root | Magisk 24.0+ |

See [aosmium-webview/README.md](aosmium-webview/README.md) for details.

### microG (`dresosmicrog`)

Systemless microG suite with bundled signature spoofing. Drop in replacement for Google Play Services. Includes GmsCore, Companion (FakeStore), GsfProxy, DroidGuard Helper, and Aurora Store. Runtime Google debloat, security hardening, and a per component bootloop sentinel are built in.

[Download latest release](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/download/microg-v2.0.0/DresOS-microG-v2_0_0.zip)

|  |  |
| --- | --- |
| microG GmsCore | 0.3.7.250932 |
| Packages | `com.google.android.gms`, `com.android.vending`, `com.google.android.gsf`, `org.microg.gms.droidguard`, `com.aurora.store` |
| Android | 8.0 through 16+ (API 26 to 36+) |
| ABI | arm, arm64, x86, x86_64 (Zygisk sigspoof on arm64 and x86_64) |
| Root | Magisk 24.0+, or KernelSU / APatch with ZygiskNext / ReZygisk |

See [microg/README.md](microg/README.md) for details.

## Roadmap

| Module | Status |
| --- | --- |
| `dresoswv` AOSmium WebView | v2.2.0 |
| `dresosmicrog` microG | v2.0.0 |
| `dresosdebloat` Debloater | Planned |
| `dresosperms` Permissions Hardener | Planned |
| `dresosafwall` AFWall+ Bootstrap | Planned |

## License

GPL-3.0.

## Links

- https://dresoperatingsystems.github.io
- https://xdaforums.com/t/dresos-the-android-defensive-security-system.4787891
