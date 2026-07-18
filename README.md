# DresOS Magisk Modules

Part of the [DresOS Android Defensive Security System](https://github.com/DresOperatingSystems/DresOS-The-Android-Defensive-Security-System).

---

## Modules

### WebView (`dresoswv`)

Replaces Android System WebView with [DresOS WebView](https://github.com/DresOperatingSystems/DresOS-WebView), our own webview to complement the module.

[Download latest release](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/download/webview-v2.2.0/DresOS-WebView-v2_2_0.zip)

|  |  |
| --- | --- |
| DresOS WebView version | 145.0.7632.120 |
| Package | `org.dresos.webview` |
| Android | 10 through 16+ (API 29 to 36+) |
| ABI | arm, arm64 |
| Root | Magisk 24.0+ |

See [webview/README.md](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/tree/main/webview) for details.

### microG (`dresosmicrog`)

Universal systemless microG suite and drop-in replacement for Google Play Services. Ships the officially signed microG GmsCore, Companion (FakeStore) and GsfProxy as privileged system apps, plus Aurora Store along with Aurora Services. It is a pure file overlay with no Zygisk payload, no Xposed, and no boot scripts, so it cannot bootloop the device and coexists cleanly with the DresOS WebView module. Signature spoofing is provided by the ROM: because the microG APKs carry the official microG key, any ROM that supports microG signature spoofing activates it automatically.

[Download latest release](https://github.com/The-DresOS-Foundation/DresOS-Magisk-Modules/releases/tag/microg-v3.1.2)

|  |  |
| --- | --- |
| microG GmsCore | 0.3.15.250932 |
| Packages | `com.google.android.gms`, `com.android.vending`, `com.google.android.gsf`, `com.aurora.store`, `com.aurora.services` |
| Android | 8.0 through 16+ (API 26 to 36+) |
| ABI | arm, arm64, x86, x86_64 (multi-ABI microG APK) |
| Signature spoofing | provided by the ROM for officially signed microG (LineageOS 2024-02-26+, e/OS, CalyxOS, iodeOS, DivestOS, and others) |
| Root | Magisk 24.0+ |

See [microg/README.md](microg/README.md) for details.

## License

GPL-3.0.

## Links

- https://dresoperatingsystems.github.io
- https://xdaforums.com/t/dresos-the-android-defensive-security-system.4787891

## Donate

> **Help fund future development.** DresOS is built by a small open source team in our spare time. If our guide, Magisk modules or app saved you a weekend of research, please tip the jar. Funds go to test devices, dev stations, and developer time on updates and future projects.

[![Please Help fund future projects and keep this one going](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dresos)
