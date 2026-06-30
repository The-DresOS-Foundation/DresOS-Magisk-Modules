#!/usr/bin/env bash
##############################################################################
#  DresOS microG  make-google-signed.sh   (stock-mode signature transplant)
#
#  Transplants the OFFICIAL Google signing certificate onto the microG core
#  APKs using apksigcopier, so the system reports microG's GmsCore, Companion
#  and GsfProxy as Google-signed. This removes the need for ROM signature
#  spoofing entirely: the resulting APKs work on stock firmware and on any
#  ROM, because they already carry Google's real certificate.
#
#  HARD LIMITATION (by design, not a bug): the copied signature is valid
#  against Google's bytes, not microG's, so these APKs verify ONLY as system
#  / privileged apps (PackageManager collects the certificate without
#  re-verifying content digests for system apps). They CANNOT be installed as
#  user apps (INSTALL_PARSE_FAILED_NO_CERTIFICATES), and microG can no longer
#  be updated from F-Droid: updates must come through a rebuilt module.
#
#  Method (validated): for each app, extract the donor's signing block,
#  extract microG's OWN block only to borrow its APKSigningBlockOffset (so the
#  output is the correct size instead of being padded up to Google's APK
#  size), then patch the donor block onto the microG APK at that offset.
#
#  Donors: provide genuine Google APKs. com.google.android.gms,
#  com.android.vending and com.google.android.gsf all share the same Google
#  signing certificate, so a single genuine Play Services APK works as the
#  donor for all three. You may instead drop per-app donors to be exact.
#
#  Usage:
#    ./make-google-signed.sh /path/to/PlayServices.apk
#    ./make-google-signed.sh                # auto-detect donors/ directory
#
#  Donor resolution order (per app), first match wins:
#    donors/gms.apk | donors/vending.apk | donors/gsf.apk   (per-app)
#    $1 (a single donor APK on the command line)            (shared)
#    donors/donor.apk                                        (shared)
#
#  Requires: apksigcopier, python3 (+ androguard for the cert check), unzip.
#  Output:   apk-google-signed/{GmsCore,Companion,GsfProxy}.apk
##############################################################################
set -euo pipefail
cd "$(dirname "$0")"

GOOGLE_CERT_SHA256="f0fd6c5b410f25cb25c3b53346c8972fae30f8ee7411df910480ad6b2d60db83"
OUT="apk-google-signed"
WORK=".sigwork"

req(){ command -v "$1" >/dev/null 2>&1 || { echo "! need '$1' on PATH"; exit 1; }; }
req apksigcopier; req python3; req unzip

SHARED_DONOR=""
[ "${1:-}" ] && SHARED_DONOR="$1"
[ -z "$SHARED_DONOR" ] && [ -f donors/donor.apk ] && SHARED_DONOR="donors/donor.apk"

donor_for(){ # per-app file name -> echoes donor path or empty
    case "$1" in
        gms)     [ -f donors/gms.apk ]     && { echo donors/gms.apk; return; } ;;
        vending) [ -f donors/vending.apk ] && { echo donors/vending.apk; return; } ;;
        gsf)     [ -f donors/gsf.apk ]     && { echo donors/gsf.apk; return; } ;;
    esac
    [ -n "$SHARED_DONOR" ] && echo "$SHARED_DONOR" || echo ""
}

# cert SHA-256 of an APK (v2/v3 or v1), androguard with logging silenced
cert_sha256(){
    python3 - "$1" <<'PY'
import sys, hashlib
try:
    from loguru import logger; logger.remove()
except Exception: pass
import logging; logging.disable(logging.CRITICAL)
from androguard.core.apk import APK
a=APK(sys.argv[1]); certs=[]
for fn in ("get_certificates_der_v3","get_certificates_der_v2"):
    try: certs += getattr(a,fn)() or []
    except Exception: pass
if not certs:
    try: certs += [c.dump() for c in (a.get_certificates() or [])]
    except Exception: pass
print(next(iter({hashlib.sha256(c).hexdigest() for c in certs}), ""))
PY
}

# central-directory offset of a zip (where a signing block must sit), decimal
cd_offset(){
    python3 - "$1" <<'PY'
import sys, struct
data=open(sys.argv[1],"rb").read()
e=data.rfind(b'PK\x05\x06')
print(struct.unpack('<I', data[e+16:e+20])[0])
PY
}

graft(){ # appName  microgApk  donorApk  outApk
    local name="$1" mg="$2" donor="$3" out="$4"
    local md="$WORK/$name-donor" mm="$WORK/$name-microg"
    rm -rf "$md" "$mm"; mkdir -p "$md" "$mm"
    echo "  [$name] donor: $donor"
    apksigcopier extract --ignore-differences "$donor" "$md" >/dev/null
    # Borrow microG's own signing-block offset so the output is correctly sized.
    if apksigcopier extract --ignore-differences "$mg" "$mm" >/dev/null 2>&1 \
         && [ -s "$mm/APKSigningBlockOffset" ]; then
        cp "$mm/APKSigningBlockOffset" "$md/APKSigningBlockOffset"
    else
        # microG APK was already stripped/unsigned: compute offset directly.
        cd_offset "$mg" > "$md/APKSigningBlockOffset"
    fi
    apksigcopier patch --ignore-differences "$md" "$mg" "$out" >/dev/null
    local got; got="$(cert_sha256 "$out")"
    if [ "$got" != "$GOOGLE_CERT_SHA256" ]; then
        echo "! [$name] output cert is $got"
        echo "! expected Google cert $GOOGLE_CERT_SHA256"
        echo "! donor is not genuinely Google-signed (re-signed by a mirror?). Aborting."
        exit 1
    fi
    echo "  [$name] OK  ->  $out  ($(stat -c%s "$out") bytes, Google cert verified)"
}

[ -f apk/GmsCore.apk ] || { echo "! apk/GmsCore.apk missing. Run refresh-upstream.sh first."; exit 1; }
gd="$(donor_for gms)"; vd="$(donor_for vending)"; sd="$(donor_for gsf)"
[ -n "$gd" ] || { echo "! No donor APK. Pass a genuine Play Services APK: ./make-google-signed.sh PlayServices.apk"; exit 1; }

echo "Transplanting Google signature onto microG core..."
rm -rf "$OUT" "$WORK"; mkdir -p "$OUT" "$WORK"
graft gms     apk/GmsCore.apk   "$gd" "$OUT/GmsCore.apk"
graft vending apk/Companion.apk "$vd" "$OUT/Companion.apk"
[ -f apk/GsfProxy.apk ] && graft gsf apk/GsfProxy.apk "$sd" "$OUT/GsfProxy.apk"
rm -rf "$WORK"
echo
echo "Done. Google-signed core in $OUT/."
echo "Build the stock-flavor module with:  GOOGLE_SIGNED=1 ./build-module.sh"
