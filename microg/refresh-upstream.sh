#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p apk

MICROG_REPO="https://microg.org/fdroid/repo"
IZZY_REPO="https://apt.izzysoft.de/fdroid/repo"

req(){ command -v "$1" >/dev/null 2>&1 || { echo "! need '$1' on PATH"; exit 1; }; }
req curl; req jq

is_apk(){ [ -s "$1" ] && [ "$(head -c2 "$1" 2>/dev/null)" = "PK" ]; }

resolve_apkname(){ # index-json packageName  ->  apkName (highest versionCode)
    printf '%s' "$1" | jq -r --arg p "$2" \
        '.packages[$p] // [] | max_by(.versionCode) | .apkName // empty'
}

MICROG_INDEX="$(curl -fsSL "$MICROG_REPO/index-v1.json")"

fetch_core(){ # packageName outName
    local pkg="$1" out="$2" apkname
    apkname="$(resolve_apkname "$MICROG_INDEX" "$pkg")"
    [ -n "$apkname" ] || { echo "! microG repo has no APK for $pkg"; exit 1; }
    curl -fSL "$MICROG_REPO/$apkname" -o "apk/$out"
    is_apk "apk/$out" || { echo "! downloaded apk/$out is not a valid APK"; exit 1; }
}

fetch_core com.google.android.gms GmsCore.apk
fetch_core com.android.vending     Companion.apk
fetch_core com.google.android.gsf  GsfProxy.apk

resolve_apkname "$MICROG_INDEX" com.google.android.gms >/dev/null
printf '%s\n' "$MICROG_INDEX" \
    | jq -r '.packages["com.google.android.gms"] | max_by(.versionCode) | .versionCode' \
    > apk/.gmscore_versioncode

if IZZY_INDEX="$(curl -fsSL "$IZZY_REPO/index-v1.json" 2>/dev/null)"; then
    fetch_aurora(){ # packageName outName label
        local pkg="$1" out="$2" label="$3" apkname
        apkname="$(resolve_apkname "$IZZY_INDEX" "$pkg")"
        if [ -z "$apkname" ]; then
                rm -f "apk/$out"; return 0
        fi
            if curl -fSL "$IZZY_REPO/$apkname" -o "apk/$out" && is_apk "apk/$out"; then
            : # ok
        else
            rm -f "apk/$out"
        fi
    }
    fetch_aurora com.aurora.store    AuroraStore.apk    "Aurora Store"
    fetch_aurora com.aurora.services AuroraServices.apk "Aurora Services"
else
    rm -f apk/AuroraStore.apk apk/AuroraServices.apk
fi

