#!/usr/bin/env bash
# Shared validation used by the connected builder and transported helpers.

valid_target_kernel() {
  [[ "$1" =~ ^4\.18\.0-553(\.[0-9]+\.[0-9]+)?\.el8_10\.x86_64$ ]]
}

require_rhel810_host() {
  local ID="" VERSION_ID=""
  [[ -r /etc/os-release ]] || { printf 'ERROR: /etc/os-release is unavailable\n' >&2; return 1; }
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "$ID" == rhel && "$VERSION_ID" == 8.10 ]] || {
    printf 'ERROR: this operation requires RHEL 8.10; detected %s %s\n' "$ID" "$VERSION_ID" >&2
    return 1
  }
}

verify_el8_rpm() {
  local path="$1" release arch remainder matched_major matched_tag
  IFS='|' read -r release arch < <(rpm -qp --qf '%{RELEASE}|%{ARCH}\n' "$path")
  [[ "$arch" =~ ^(x86_64|noarch)$ ]] || return 1
  # RHEL AppStream artifacts can carry e.g. module+el8.10.0+21673+5ce1591e
  # instead of a conventional .el8/_10 dist tag. Both are EL8 content.
  [[ "$release" =~ \.el8(_[0-9]+)?(\.[0-9]+)*$ \
     || "$release" =~ \.module\+el8(\.[0-9]+)*\+[[:alnum:]_.+]+$ ]] || return 1
  # A mixed release must not pass merely because its final tag says EL8.
  remainder="$release"
  while [[ "$remainder" =~ (^|[.+])el([0-9]+)([._+]|$) ]]; do
    matched_tag="${BASH_REMATCH[0]}"
    matched_major="${BASH_REMATCH[2]}"
    [[ "$matched_major" == 8 ]] || return 1
    remainder="${remainder#*"$matched_tag"}"
  done
  return 0
}

verify_open_dkms() {
  local path="$1" driver="$2" name version license
  IFS='|' read -r name version license < <(rpm -qp --qf '%{NAME}|%{VERSION}|%{LICENSE}\n' "$path")
  [[ "$name" == kmod-nvidia-open-dkms && "$version" == "$driver" && "$license" =~ (GPL|MIT) ]] \
    && verify_el8_rpm "$path"
}

verify_open_kmod() {
  local path="$1" kernel="$2" driver="$3" name version license provides conflicts
  IFS='|' read -r name version license < <(rpm -qp --qf '%{NAME}|%{VERSION}|%{LICENSE}\n' "$path")
  provides="$(rpm -qp --provides "$path")" || return 1
  conflicts="$(rpm -qp --conflicts "$path")" || return 1
  [[ "$name" == kmod-nvidia-open* && "$name" != *dkms* && "$version" == "$driver" \
     && "$license" =~ (GPL|MIT) && "$provides" == *"kmod(nvidia.ko)"* \
     && "$provides" == *"${kernel}"* && "$conflicts" != *"kmod-nvidia-open"* ]] \
    && verify_el8_rpm "$path"
}

validate_gpu_state() {
  local expected_kernel="$1" expected_driver="$2" expected_gpus="$3"
  local version_file="${4:-/proc/driver/nvidia/version}" versions count
  [[ "$(uname -r)" == "$expected_kernel" ]] \
    || { printf 'ERROR: running kernel does not match %s\n' "$expected_kernel" >&2; return 1; }
  command -v nvidia-smi >/dev/null 2>&1 \
    || { printf 'ERROR: nvidia-smi is not installed\n' >&2; return 1; }
  nvidia-smi || return 1
  versions="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)" || return 1
  [[ -n "$versions" ]] \
    || { printf 'ERROR: no GPU driver versions were reported\n' >&2; return 1; }
  printf '%s\n' "$versions" | awk -v wanted="$expected_driver" '$0 != wanted {bad=1} END {exit bad}' \
    || { printf 'ERROR: every GPU must report driver %s\n' "$expected_driver" >&2; return 1; }
  grep -Fq 'Open Kernel Module' "$version_file" \
    || { printf 'ERROR: the loaded NVIDIA module is not confirmed as Open\n' >&2; return 1; }
  count="$(nvidia-smi --query-gpu=index --format=csv,noheader | wc -l)" || return 1
  [[ "$count" -eq "$expected_gpus" ]] \
    || { printf 'ERROR: expected %s GPUs; nvidia-smi found %s\n' "$expected_gpus" "$count" >&2; return 1; }
}
