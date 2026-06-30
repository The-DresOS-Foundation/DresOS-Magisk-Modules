#!/usr/bin/env bash
##############################################################################
#  DresOS microG  refresh-upstream.sh
#
#  Downloads the APKs that build-module.sh needs into ./apk/.
#
#  microG core (GmsCore, Companion, GsfProxy) comes from microG's OFFICIAL
#  F-Droid repo, which ships the officially-signed binaries that
#  build-module.sh verifies. They update often, so they are fetched latest by
#  parsing the repo index (no hard-coded filenames, so a new versionCode can
#  never 404 the pipeline).
#
#  DroidGuard is NO LONGER fetched: microG integrated DroidGuard into GmsCore,
#  removed the standalone org.microg.gms.droidguard from its repo, and the old
#  download URL now 404s. There is nothing to download.
#
#  Aurora Store and Aurora Services are pulled by index from the IzzyOnDroid
#  repo. They are best-effort: if the repo is briefly unavailable the core
#  microG build still proceeds, because Aurora is a convenience, not core.
##############################################################################
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p apk

MICROG_REPO="https://microg.org/fdroid/repo"
IZZY_REPO="https://apt.izzysoft.de/fdroid/repo"

req(){ command -v "$1" >/dev/null 2>&1 || { echo "! need '$1' on PATH"; exit 1; }; }
req curl; req jq

# Verify a downloaded file is actually an APK (ZIP magic "PK"), not an HTML
# error page saved with a 200. This is the check that was missing before.
is_apk(){ [ -s "$1" ] && [ "$(head -c2 "$1" 2>/dev/null)" = "PK" ]; }

resolve_apkname(){ # index-json packageName  ->  apkName (highest versionCode)
    printf '%s' "$1" | jq -r --arg p "$2" \
        '.packages[$p] // [] | max_by(.versionCode) | .apkName // empty'
}

echo "Fetching microG F-Droid index..."
MICROG_INDEX="$(curl -fsSL "$MICROG_REPO/index-v1.json")"

fetch_core(){ # packageName outName
    local pkg="$1" out="$2" apkname
    apkname="$(resolve_apkname "$MICROG_INDEX" "$pkg")"
    [ -n "$apkname" ] || { echo "! microG repo has no APK for $pkg"; exit 1; }
    echo "  $pkg -> $apkname"
    curl -fSL "$MICROG_REPO/$apkname" -o "apk/$out"
    is_apk "apk/$out" || { echo "! downloaded apk/$out is not a valid APK"; exit 1; }
}

fetch_core com.google.android.gms GmsCore.apk
fetch_core com.android.vending     Companion.apk
fetch_core com.google.android.gsf  GsfProxy.apk

# Record the latest GmsCore versionCode so the workflow can tell when microG moved.
resolve_apkname "$MICROG_INDEX" com.google.android.gms >/dev/null
printf '%s\n' "$MICROG_INDEX" \
    | jq -r '.packages["com.google.android.gms"] | max_by(.versionCode) | .versionCode' \
    > apk/.gmscore_versioncode

# --- Aurora (best-effort, by index from IzzyOnDroid) -------------------------
echo "Fetching IzzyOnDroid index for Aurora..."
if IZZY_INDEX="$(curl -fsSL "$IZZY_REPO/index-v1.json" 2>/dev/null)"; then
    fetch_aurora(){ # packageName outName label
        local pkg="$1" out="$2" label="$3" apkname
        apkname="$(resolve_apkname "$IZZY_INDEX" "$pkg")"
        if [ -z "$apkname" ]; then
            echo "  ! $label ($pkg) not found in IzzyOnDroid index; skipping (optional)."
            rm -f "apk/$out"; return 0
        fi
        echo "  $pkg -> $apkname"
        if curl -fSL "$IZZY_REPO/$apkname" -o "apk/$out" && is_apk "apk/$out"; then
            : # ok
        else
            echo "  ! $label download failed or invalid; skipping (optional)."
            rm -f "apk/$out"
        fi
    }
    fetch_aurora com.aurora.store    AuroraStore.apk    "Aurora Store"
    fetch_aurora com.aurora.services AuroraServices.apk "Aurora Services"
else
    echo "  ! IzzyOnDroid index unavailable; skipping Aurora (optional)."
    rm -f apk/AuroraStore.apk apk/AuroraServices.apk
fi

echo "Done. microG core is in apk/; Aurora included when available."
echo "build-module.sh will verify the official microG key on the core APKs."
