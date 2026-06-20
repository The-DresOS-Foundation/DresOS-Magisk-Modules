#!/usr/bin/env bash
##############################################################################
#  DresOS microG  refresh-upstream.sh
#
#  Downloads the six APKs that build-module.sh needs into ./apk/.
#
#  The three microG core components come from microG's OFFICIAL F-Droid repo,
#  which ships the officially-signed binaries (the same key build-module.sh
#  verifies). They update often, so they are always fetched latest.
#
#  DroidGuard Helper and the two Aurora apps are not in the microG repo and
#  change rarely, so you set their download URLs once below.
##############################################################################
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p apk

MICROG_REPO="https://microg.org/fdroid/repo"

# --- set these three once (stable components, not in the microG repo) --------
# DroidGuard Helper (org.microg.gms.droidguard)
# Available from: https://f-droid.org/en/packages/org.microg.gms.droidguard
# or direct from repo: https://repo.microg.org/fdroid/repo
DROIDGUARD_URL="https://f-droid.org/repo/org.microg.gms.droidguard_20700.apk"

# Aurora Store (com.aurora.store)
# Latest releases: https://gitlab.com/AuroraOSS/AuroraStore/-/releases
AURORA_STORE_URL="https://gitlab.com/AuroraOSS/AuroraStore/-/releases"

# Aurora Services (com.aurora.services)
# Releases: https://gitlab.com/AuroraOSS/AuroraServices/-/releases
AURORA_SERVICES_URL="https://gitlab.com/AuroraOSS/AuroraServices/-/releases"


req(){ command -v "$1" >/dev/null 2>&1 || { echo "! need '$1' on PATH"; exit 1; }; }
req curl; req jq

echo "Fetching microG F-Droid index..."
INDEX="$(curl -fsSL "$MICROG_REPO/index-v1.json")"

fetch_fdroid(){ # packageName outName
    local pkg="$1" out="$2" apkname
    apkname="$(printf '%s' "$INDEX" | jq -r --arg p "$pkg" \
        '.packages[$p] | max_by(.versionCode) | .apkName')"
    [ -n "$apkname" ] && [ "$apkname" != "null" ] \
        || { echo "! microG repo has no APK for $pkg"; exit 1; }
    echo "  $pkg -> $apkname"
    curl -fsSL "$MICROG_REPO/$apkname" -o "apk/$out"
}

fetch_fdroid com.google.android.gms GmsCore.apk
fetch_fdroid com.android.vending     Companion.apk
fetch_fdroid com.google.android.gsf  GsfProxy.apk

# Record the latest GmsCore versionCode so the workflow can tell when microG moved.
printf '%s\n' "$INDEX" \
    | jq -r '.packages["com.google.android.gms"] | max_by(.versionCode) | .versionCode' \
    > apk/.gmscore_versioncode

fetch_pinned(){ # url outName label
    local url="$1" out="$2" label="$3"
    [ -n "$url" ] || { echo "! $label URL is not set in refresh-upstream.sh (needs apk/$out)"; exit 1; }
    echo "  $label -> apk/$out"
    curl -fsSL "$url" -o "apk/$out"
}
fetch_pinned "$DROIDGUARD_URL"      DroidGuard.apk      "DroidGuard Helper"
fetch_pinned "$AURORA_STORE_URL"    AuroraStore.apk     "Aurora Store"
fetch_pinned "$AURORA_SERVICES_URL" AuroraServices.apk  "Aurora Services"

echo "Done. apk/ now holds all six. build-module.sh will verify the official microG key."
