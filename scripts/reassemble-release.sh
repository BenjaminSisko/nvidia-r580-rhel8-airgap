#!/usr/bin/env bash
# Reassemble the immutable October 30, 2026 release on Linux or macOS.
set -Eeuo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
archive=nvidia-r580-rhel8-driver-repo-20261030.tar.gz
expected=7c55e4f252661830ca917949bfda142ddbf7d4f5ade79235b4a09c3e1c1dc8e7
if command -v sha256sum >/dev/null 2>&1; then
  checksum=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  checksum=(shasum -a 256)
else
  printf 'ERROR: install sha256sum or shasum before verification.\n' >&2
  exit 1
fi

"${checksum[@]}" -c RELEASE-SHA256SUMS.txt
if [[ -e "$archive" ]]; then
  printf '%s  %s\n' "$expected" "$archive" | "${checksum[@]}" -c -
else
  temporary="$(mktemp "./${archive}.assembling.XXXXXXXX")"
  trap 'rm -f -- "$temporary"' EXIT
  cat -- "$archive.part-aa" "$archive.part-ab" > "$temporary"
  printf '%s  %s\n' "$expected" "$temporary" | "${checksum[@]}" -c -
  mv -- "$temporary" "$archive"
  trap - EXIT
fi
"${checksum[@]}" -c "$archive.sha256"
printf '\nVerified complete archive: %s\n' "$archive"
printf 'Extract with: tar -xzf %s\n' "$archive"
printf 'Then read: repo-bundle/docs/ON-SITE-QUICKSTART.md\n'
