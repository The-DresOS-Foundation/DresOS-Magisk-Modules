#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

NEW_GMS="$(cat apk/.gmscore_versioncode)"
OLD_GMS="$(cat UPSTREAM_GMSCORE 2>/dev/null || echo 0)"

if [ "$NEW_GMS" = "$OLD_GMS" ]; then
    echo "changed=false" >> "$OUT"
    exit 0
fi

CUR_VER="$(grep '^version=' module.prop | cut -d= -f2 | sed 's/^v//')"
CUR_VC="$(grep '^versionCode=' module.prop | cut -d= -f2)"
MA="${CUR_VER%%.*}"; REST="${CUR_VER#*.}"; MI="${REST%%.*}"; PA="${REST#*.}"
NEW_VER="v${MA}.${MI}.$((PA+1))"
NEW_VC="$((CUR_VC+1))"
ZIP="DresOS-microG-$(echo "$NEW_VER" | tr '.' '_').zip"

sed -i "s/^version=.*/version=${NEW_VER}/"          module.prop
sed -i "s/^versionCode=.*/versionCode=${NEW_VC}/"   module.prop

cat > update.json <<JSON
{
    "version": "${NEW_VER}",
    "versionCode": ${NEW_VC},
    "zipUrl": "https://github.com/The-DresOS-Foundation/DresOS-Magisk-Modules/releases/download/microg-${NEW_VER}/${ZIP}",
    "changelog": "https://raw.githubusercontent.com/The-DresOS-Foundation/DresOS-Magisk-Modules/main/microg/CHANGELOG.md"
}
JSON

TMP="$(mktemp)"
{
    echo "## ${NEW_VER}"
    echo ""
    echo "- Auto-update: refreshed the officially-signed microG core (GmsCore versionCode ${NEW_GMS})."
    echo ""
    cat CHANGELOG.md 2>/dev/null || true
} > "$TMP"
mv "$TMP" CHANGELOG.md

echo "$NEW_GMS" > UPSTREAM_GMSCORE

{
    echo "changed=true"
    echo "newver=${NEW_VER}"
    echo "zip=${ZIP}"
} >> "$OUT"
