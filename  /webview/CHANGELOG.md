## Unreleased

- Switched the bundled WebView engine from AOSmium (AXP.OS) to DresOS WebView, our own Chromium build from Cromite, signed with the DresOS release key.
- The static RRO now whitelists org.dresos.webview with the DresOS signing certificate in config_webview_packages.
- Updating over the AOSmium build swaps AOSmium out for DresOS WebView in place (same module id), clearing the stale provider selection on boot.
- arm64 runs the DresOS WebView engine. 32-bit arm (armeabi-v7a) runs a bundled secondary engine so the module still covers 32-bit devices the arm64 build cannot, until a 32-bit DresOS WebView build ships.
- The static RRO whitelists both engines in config_webview_packages; customize.sh selects the engine for the device ABI at flash time, and service.sh activates whichever one landed.
- Activation via cmd webviewupdate, the post-fs-data bootloop sentinel, the inert-mode fallback, and the recovery-safe stock WebView restore are unchanged.

# DresOS AOSmium WebView changelog

## v2.2.0

Adds automatic stock WebView removal and raises the supported Android range.

### Fixed

- Fixed a parser bug in service.sh that always misread the dumpsys
  webviewupdate output. The old awk field split on the first parenthesis
  in "Current WebView package (name, version): (org.axpos.aosmium_wv, ...)"
  and returned the literal text "name" instead of the package name, so
  the post activation verification always failed and the module flipped
  itself into inert mode even when AOSmium had activated correctly. The
  parser now extracts the package from the second parenthesised group.
- Raised the Android API ceiling. v2.1.0 aborted installation on API 36
  (Android 16), which is why Pixel 9 Pro XL on LineageOS 23 could only
  install after manually editing customize.sh. The module now treats
  Android 16 (API 36) as the highest tested version and warns but
  proceeds on anything newer, instead of aborting. WebViewUpdateService,
  config_webview_packages, RRO handling, and cmd webviewupdate are
  unchanged through API 36.

### Added

- Automatic stock WebView removal. After AOSmium is confirmed as the
  active provider via dumpsys, service.sh disables the stock Google or
  AOSP WebView with pm disable-user --user 0. This runs only after
  verification, so the device always has at least one valid WebView
  provider and cannot reach a zero provider state. The Trichrome library
  and Google Chrome are never touched, so Chrome keeps working.
- Opt out. Create /data/adb/dresoswv_keep_stock_webview before flashing
  to keep the stock WebView enabled.
- Recovery safe restore. service.sh and uninstall.sh both plant a one
  shot self deleting trampoline at
  /data/adb/post-fs-data.d/zz_dresoswv_restore_wv.sh. Magisk keeps
  executing post-fs-data.d scripts even after the module is removed,
  including removal via recovery where uninstall.sh never runs. The
  trampoline no ops while the module is present and re enables the stock
  WebView once the module is gone, then deletes itself. This closes the
  one real risk with pm disable-user, which is that its disabled state
  lives in /data and survives module removal.
- Post disable re verification. After disabling the stock WebView,
  service.sh re reads dumpsys. If AOSmium is somehow no longer active it
  immediately re enables the stock package and flips to inert mode so
  the device is never left without a working WebView.

### Changed

- Magisk floor raised from 24.0 to 29.0. The rewritten magic mount
  backend and Android 16 QPR2 sepolicy support landed in the v29 to v30
  series and this module relies on correct /product magic mount on
  modern Android.
- module.prop description and README updated to document the disable
  step, the opt out file, and the new supported range.

### Verified

- Package name: org.axpos.aosmium_wv
- versionCode: 772704901 (arm64), 772704900 (arm)
- targetSdkVersion: 36
- Signing cert SHA-256: 005C9805D501BF50C1A8BFD3204B6908843088581FDCF3DB8AB4F688FFC0E7B6

## v2.1.0

Complete rewrite of the activation pipeline.

### Fixed

- Overlay APK is now properly compiled binary AXML with the AXP.OS certificate embedded.
- Overlay targets the framework android package instead of com.android.webview.
- pm install removed. APK placed in systemless tree at system/product/app/AOSmiumWebView/.
- Magisk replace markers on com.android.webview removed.
- Activation runs in service.sh after sys.boot_completed via cmd webviewupdate.

### Added

- Bootloop sentinel in post-fs-data.sh.
- Inert mode flag set automatically on activation failure.
- Logs at /data/adb/modules/dresoswv/logs/.
- ABI gate, APEX guard, Samsung One UI detection.
