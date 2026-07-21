#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for t in aapt python3 openssl zip; do command -v "$t" >/dev/null 2>&1 || exit 1; done
for a in GmsCore Companion GsfProxy; do [ -f "apk/$a.apk" ] || exit 1; done

CUR=$(grep '^version=' module.prop | cut -d= -f2 | sed 's/^v//')
if [ "${1:-}" != "" ]; then
    NEW="${1#v}"
else
    NEW=$(printf '%s' "$CUR" | awk -F. '{printf "%d.%d.%d",$1,$2,$3+1}')
fi
CODE=$(printf '%s' "$NEW" | awk -F. '{printf "%d%02d%02d",$1,$2,$3}')
ZIP="DresOS-microG-v$(printf '%s' "$NEW" | tr . _).zip"

VC=$(aapt dump badging apk/GmsCore.apk | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
VN=$(aapt dump badging apk/GmsCore.apk | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")

sed -i "s/^version=.*/version=v$NEW/; s/^versionCode=.*/versionCode=$CODE/" module.prop
python3 - "$NEW" "$CODE" "$ZIP" <<'PYEOF'
import sys,re
new,code,zipn=sys.argv[1],sys.argv[2],sys.argv[3]
p="update.json";s=open(p).read()
s=re.sub(r'"version":\s*"[^"]*"',f'"version": "v{new}"',s)
s=re.sub(r'"versionCode":\s*[0-9]+',f'"versionCode": {code}',s)
s=re.sub(r'microg-v[0-9.]+',f'microg-v{new}',s)
s=re.sub(r'DresOS-microG-v[0-9_]+\.zip',zipn,s)
open(p,"w").write(s)
PYEOF
printf '%s\n' "$VC" > apk/.gmscore_versioncode
[ -n "$VN" ] && sed -i "s/microG GmsCore [0-9.]*, versionCode [0-9]* (official/microG GmsCore $VN, versionCode $VC (official/" README.md 2>/dev/null || true

bash build-module.sh
