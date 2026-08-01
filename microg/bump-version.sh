#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

NEW_STATE="apk/.upstream_versions"
OLD_STATE="UPSTREAM_VERSIONS"

not_changed() { echo "changed=false" >> "$OUT"; exit 0; }

[ -f "$NEW_STATE" ] || not_changed
[ -s "$NEW_STATE" ] || not_changed
if [ -f "$OLD_STATE" ] && cmp -s "$OLD_STATE" "$NEW_STATE"; then
    not_changed
fi

MOVED=""
note() { MOVED="${MOVED}${MOVED:+, }$1"; }

while read -r pkg code; do
    [ -n "$pkg" ] || continue
    prev=""
    [ -f "$OLD_STATE" ] && prev=$(awk -v p="$pkg" '$1==p{print $2}' "$OLD_STATE")
    [ "$prev" = "$code" ] && continue
    if [ -z "$prev" ]; then note "$pkg added at $code"; else note "$pkg $prev to $code"; fi
done < "$NEW_STATE"

if [ -f "$OLD_STATE" ]; then
    while read -r pkg code; do
        [ -n "$pkg" ] || continue
        grep -q "^$pkg " "$NEW_STATE" || note "$pkg dropped upstream"
    done < "$OLD_STATE"
fi

[ -n "$MOVED" ] || MOVED="bundled app versions changed"

CUR_VER="$(grep '^version=' module.prop | cut -d= -f2 | sed 's/^v//')"
CUR_VC="$(grep '^versionCode=' module.prop | cut -d= -f2)"
MA="${CUR_VER%%.*}"; REST="${CUR_VER#*.}"; MI="${REST%%.*}"; PA="${REST#*.}"
NEW_VER="v${MA}.${MI}.$((PA+1))"
NEW_VC="$((CUR_VC+1))"
ZIP="DresOS-microG-$(echo "$NEW_VER" | tr '.' '_').zip"

sed -i "s/^version=.*/version=${NEW_VER}/"        module.prop
sed -i "s/^versionCode=.*/versionCode=${NEW_VC}/" module.prop

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
    echo "- Automatic refresh of the bundled apps: ${MOVED}."
    echo ""
    cat CHANGELOG.md 2>/dev/null || true
} > "$TMP"
mv "$TMP" CHANGELOG.md

cp "$NEW_STATE" "$OLD_STATE"
awk '$1=="com.google.android.gms"{print $2}' "$NEW_STATE" > UPSTREAM_GMSCORE

{
    echo "changed=true"
    echo "newver=${NEW_VER}"
    echo "zip=${ZIP}"
    echo "moved=${MOVED}"
} >> "$OUT"
