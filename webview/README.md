# DresOS WebView

Systemless replacement of the Android System WebView with **DresOS WebView**, a
Chromium engine built from [Cromite](https://github.com/uazo/cromite) with
Google services and telemetry stripped and Cromite's privacy and security
hardening throughout.

The System WebView is the engine hundreds of apps use internally whenever they
render web content. By default that engine is Google's. This module replaces it
device-wide with DresOS's own build, signed with the DresOS release key, in a
single Magisk flash.

The engine is also published on its own as a standalone signed APK with
IzzyOnDroid and Obtainium support, at
[github.com/DresOperatingSystems/DresOS-WebView](https://github.com/DresOperatingSystems/DresOS-WebView).

## What it does

1. Validates the host: Magisk 29.0 or newer, Android 10 through 16, arm64.
   Aborts cleanly on other ABIs and on devices that ship WebView as an APEX.
2. Drops the signed DresOS WebView APK into the systemless tree at
   `system/product/app/DresOSWebView/` via Magisk magic mount, so the framework
   `MATCH_FACTORY_ONLY` scan sees it as a preinstalled provider.
3. Places a static RRO that adds `org.dresos.webview` plus the DresOS signing
   certificate to the framework `config_webview_packages` allowlist. The Google
   and AOSP WebView packages are kept as fallbacks so removing this module can
   never leave the device without a valid provider.
4. After boot complete, `service.sh` runs
   `cmd webviewupdate set-webview-implementation org.dresos.webview` to promote
   it to the active provider, with a `settings put global webview_provider`
   fallback write, then verifies the selection via `dumpsys`.
5. Once DresOS WebView is the confirmed active provider, the stock WebView is
   disabled (not deleted) and a recovery-safe restore trampoline is planted, so
   the stock WebView always returns on module removal. Opt out by creating
   `/data/adb/dresoswv_keep_stock_webview` before flashing.

## Bootloop safety

- **post-fs-data sentinel:** a `boot_pending` marker is dropped each boot and
  cleared on successful activation. A stale marker on the next boot means the
  previous boot crashed, and the module auto-disables itself.
- **Inert mode:** set on any activation failure so no further activation is
  attempted on later boots, preventing retry storms.

## Verify

```
adb shell dumpsys webviewupdate | grep "Current WebView package"
```

Expected:

```
Current WebView package (name, version): (org.dresos.webview, <version>)
```

## Updating from the AOSmium build

If you previously installed the AOSmium build of this module, just flash this
version over it from the Magisk app. It keeps the same module id, so it updates
in place: the AOSmium engine and its allowlist entry are dropped and replaced
with DresOS WebView, the stale provider selection is cleared, and DresOS WebView
is promoted on the next boot. There is no need to uninstall the old module first.

## Build

The flashable zip is assembled by `build-module.sh`, which needs the compiled
RRO (`overlay/DresOSWebViewOverlay.apk`, built by `overlay/build.sh`) and the
signed DresOS WebView arm64 APK at `apks/webview-arm64.apk`.

## License

GPL-3.0. DresOS WebView is a derivative of Cromite and Chromium. Project site:
[dresoperatingsystems.github.io](https://dresoperatingsystems.github.io).
