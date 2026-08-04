## v2.3.2

- Rolled the arm64 engine back to the Chromium 145 build, the one this module shipped through v2.2.x. The Cromite 148 engine introduced in v2.3.0 crashes the renderer on real pages. It was compiled with the dangling pointer check left on and set to fatal, which release Chromium ships disabled, so a page that loads fine everywhere else aborts its render process the moment that check trips. Until the 148 engine is rebuilt with that check off, the known good 145 engine goes back in.
- Nothing else changed. The 32 bit AOSmium backup, the per architecture overlays, the installer and the activation flow are all exactly as they were in v2.3.1.

## v2.3.1

- Fixed the overlay offering both engines on the same device. The installer has always placed only one engine, chosen by the device architecture, but the overlay whitelisted both, so an arm64 phone advertised AOSmium as a selectable WebView provider even though the module never installed it there. AOSmium is the engine for the architectures the DresOS build cannot serve, not an alternative sitting next to it. There are now two overlays, one per architecture, and each device gets only the one that matches it plus the stock fallbacks.

## v2.3.0

- Carries the new DresOS WebView engine, rebuilt on Cromite 148.0.7778.168. That is three Chromium majors on from the engine the module shipped before, so it brings every upstream security fix in between.
- AOSmium is back as the backup engine on 32 bit, and it is a much newer build than the one that was bundled before. It is credited to AXP.OS in the installer, the overlay and this repository rather than presented as ours.
- The bundled engines now update themselves. A release workflow pulls the DresOS engine from its own releases and the newest stable AOSmium from the AXP.OS repository, checks both against their pinned signing certificates, builds the module and publishes it. Pre-releases are skipped, because AXP.OS marks untested builds that way.
- The signing key never reaches the workflow. The engine is built and signed on the maintainer's machine and the workflow only packages and publishes what is already signed.

## v2.2.2

- AOSmium is back as the backup engine. It was removed in v2.2.1, which left every armeabi-v7a device with nothing at all, and that was the wrong call. The module ships DresOS WebView as the primary provider on arm64 and AOSmium by AXP.OS as the backup on 32 bit, exactly as it did before, with AOSmium credited to AXP.OS in the installer, the overlay and this repository rather than presented as ours.
- There is no 32 bit DresOS engine and none is promised. Upstream publishes System WebView for arm64 and x64 only, so a 32 bit DresOS build would need Chromium compiled from source. Until that happens AOSmium covers those devices, which is what it was always there for.
- Added an automatic build and release workflow. Pushing a webview tag pulls the published DresOS engine from the DresOS-WebView releases, pulls AOSmium from the pinned URL in webview/engines.conf, verifies both against their pinned signing certificates, builds the module and publishes the release. The release key never leaves the build host; the workflow only packages and publishes.
- Added tools/verify-engines.sh, which checks both bundled engines against their expected certificate and package name. The build refuses to run if either is wrong, because the overlay names those certificates and a mismatch produces a module that installs and then silently cannot be selected.

## v2.2.1

- Repointed the in module update check and the issues link at The DresOS Foundation. They still pointed at the old account, so update checks were resolving through a redirect or not at all. The microG module had this fixed in v3.1.3; this module was missed.
- Added minMagisk to module.prop so Magisk enforces the same floor the installer checks, rather than letting the flash start and then abort.
- The installer banner now reads the version from module.prop instead of carrying its own hardcoded copy.
- Corrected the README: the standalone engine APK is distributed through its own GitHub releases only. It is too large for IzzyOnDroid, and the link pointed at the old account.
- Dropped the 32 bit path. armeabi-v7a devices were being given AOSmium by AXP.OS, another project's engine, presented as a DresOS one. Rather than keep shipping someone else's build under our name, the module is arm64 only until a 32 bit DresOS WebView engine exists. A 32 bit device is now told that at flash time and nothing on it is touched. The AOSmium entry is gone from the RRO as well.

## v2.2.0

- Switched the bundled WebView engine from AOSmium (AXP.OS) to DresOS WebView, our own Chromium build from Cromite, signed with the DresOS release key.
- The static RRO now whitelists org.dresos.webview with the DresOS signing certificate in config_webview_packages.
- Updating over the AOSmium build swaps AOSmium out for DresOS WebView in place (same module id), clearing the stale provider selection on boot.
- arm64 runs the DresOS WebView engine. 32 bit arm (armeabi-v7a) runs a bundled secondary engine so the module still covers 32 bit devices the arm64 build cannot, until a 32 bit DresOS WebView build ships.
- The static RRO whitelists both engines in config_webview_packages; customize.sh selects the engine for the device ABI at flash time, and service.sh activates whichever one landed.
- Activation via cmd webviewupdate, the post-fs-data bootloop sentinel, the inert mode fallback, and the recovery safe stock WebView restore are unchanged.

# Earlier releases, when this module shipped the AOSmium engine

## v2.2.0 (AOSmium engine, superseded)

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
