#!/usr/bin/env bash
# fetchurl stops at HTTP success, including an empty or corrupt mirror response.
# Try the remaining pinned sources before Nix performs its final hash check.
set -euo pipefail

expected=$1
download=$2
shift 2

# Match fetchurl's certificate handling inside the fixed-output sandbox. The
# pinned content digest remains mandatory regardless of transport trust.
curl_args=()
if [[ ! -f ${SSL_CERT_FILE:-} ]]; then
  curl_args+=(--insecure)
fi

matches() {
  [[ -f "$download" ]] && [[ $(sha256sum < "$download") == "$expected  -" ]]
}

if matches; then
  exit 0
fi

for url in "$@"; do
  echo "Zig archive checksum mismatch; trying $url" >&2
  # Never append a different mirror's bytes to a partial or invalid response.
  rm -f -- "$download"
  if curl "${curl_args[@]}" --fail --location --connect-timeout 10 --max-time 120 \
      --retry 2 --retry-max-time 180 --output "$download" "$url" && matches; then
    exit 0
  fi
done

echo "No Zig mirror supplied the pinned SHA-256 archive" >&2
exit 1
