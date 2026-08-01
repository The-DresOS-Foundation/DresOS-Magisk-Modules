#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
. ./engines.conf

check() {
    local apk="$1" want="$2" pkg="$3" label="$4" got name
    [ -f "$apk" ] || { echo "! $label is missing at $apk" >&2; exit 1; }
    got=$(apksigner verify --print-certs "$apk" | sed -n 's/.*SHA-256 digest: *//p' | head -1 | tr 'A-F' 'a-f')
    if [ "$got" != "$want" ]; then
        echo "! $label certificate is $got" >&2
        echo "! expected $want" >&2
        echo "! The module overlay names the expected one, so this build would not activate." >&2
        exit 1
    fi
    name=$(aapt dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")
    if [ "$name" != "$pkg" ]; then
        echo "! $label package is $name, expected $pkg" >&2
        exit 1
    fi
    echo "  $label ok, $name"
}

check apks/webview-arm64.apk  "$ENGINE_CERT_SHA256"  org.dresos.webview     "DresOS WebView arm64"
check apks/aosmium-arm32.apk  "$AOSMIUM_CERT_SHA256" org.axpos.aosmium_wv   "AOSmium arm32"
