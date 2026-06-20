#!/usr/bin/env bash
##############################################################################
#  DresOS microG  bump-version.sh
#
#  Compares the freshly fetched GmsCore versionCode (written by
#  refresh-upstream.sh into apk/.gmscore_versioncode) against the last-built
#  value in UPSTREAM_GMSCORE. If microG moved, bumps the DresOS module
#  version (patch +1, versionCode +1) in module.prop and update.json, adds a
#  CHANGELOG entry, and records the new upstream versionCode.
#
#  Emits changed/newver/zip to $GITHUB_OUTPUT for the workflow to act on.
##############################################################################
set -euo pipefail
cd "$(dirname "$0")"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

NEW_GMS="$(cat apk/.gmscore_versioncode)"
OLD_GMS="$(cat UPSTREAM_GMSCORE 2>/dev/null || echo 0)"

if [ "$NEW_GMS" = "$OLD_GMS" ]; then
    echo "changed=false" >> "$OUT"
    echo "No upstream microG change (GmsCore versionCode $NEW_GMS). Nothing to do."
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
    "zipUrl": "https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/download/microg-${NEW_VER}/${ZIP}",
    "changelog": "https://raw.githubusercontent.com/DresOperatingSystems/DresOS-Magisk-Modules/main/microg/CHANGELOG.md"
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
echo "Bumped module to ${NEW_VER} (versionCode ${NEW_VC}); bundled GmsCore versionCode ${NEW_GMS}."
