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
  # Official EL8 open-DKMS RPMs use the umbrella "NVIDIA License" header.
  # Native inspection of official 580.196.07 found kernel-open/nvidia/nv.c
  # with SPDX-License-Identifier: MIT despite that umbrella RPM license header.
  # Flavor comes from the exact vendor package identity, never that header.
  # The builder/importer separately require its valid NVIDIA RPM signature;
  # postreboot validation proves that the loaded module identifies as Open.
  [[ "$name" == kmod-nvidia-open-dkms && "$version" == "$driver" ]] \
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


check_bundle_output() {
  local bundle="$1" resume="$2"
  if [[ -e "$bundle" || -L "$bundle" ]]; then
    [[ -d "$bundle" && ! -L "$bundle" ]] \
      || { printf 'ERROR: existing repo-bundle must be a regular directory\n' >&2; return 1; }
    [[ ! -e "$bundle/MANIFEST.txt" && ! -L "$bundle/MANIFEST.txt" \
       && ! -e "$bundle/SHA256SUMS" && ! -L "$bundle/SHA256SUMS" ]] \
      || { printf 'ERROR: completed/manifested bundles cannot be resumed; choose a fresh --output\n' >&2; return 1; }
    ((resume == 1)) \
      || { printf 'ERROR: output contains an incomplete repo-bundle; inspect it and use --resume explicitly, or choose a fresh --output\n' >&2; return 1; }
  elif ((resume)); then
    printf 'ERROR: --resume requires an existing incomplete repo-bundle\n' >&2
    return 1
  fi
  return 0
}

# kernel-devel must match the running kernel. Headers are a userspace ABI
# package and are not installonly: retain existing headers, including newer ones.
dkms_dependency_specs() {
  local kernel="$1"
  printf '%s\n' gcc gcc-c++ make dkms elfutils-libelf-devel python36 "kernel-devel-${kernel}"
  if ! rpm -q kernel-headers >/dev/null 2>&1; then
    printf '%s\n' "kernel-headers-${kernel}"
  fi
}

verify_driver_only_rpm() {
  local name
  name="$(rpm -qp --qf '%{NAME}' "$1")" || return 1
  case "$name" in
    cuda*|cudnn*|libcudnn*|tensorrt*|libnvinfer*|libcublas*|libcufft*|libcurand*|libcusolver*|libcusparse*|libnpp*|libnvjpeg*|nsight*|nvidia-cuda-toolkit*)
      printf 'ERROR: driver-only bundle cannot include toolkit/library package %s\n' "$name" >&2
      return 1 ;;
  esac
}

place_rpm() {
  local source="$1" destination="$2" target
  [[ -f "$source" && ! -L "$source" && "$source" == *.rpm ]] || return 1
  mkdir -p -- "$destination" || return 1
  target="$destination/$(basename -- "$source")"
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -f "$target" && ! -L "$target" ]] && cmp -s -- "$source" "$target" \
      || { printf 'ERROR: cached RPM differs from resolved package: %s\n' "$target" >&2; return 1; }
  else
    # Same-filesystem hardlinks avoid another multi-gigabyte copy. No metadata
    # or manifests are imported; every linked RPM is verified again before use.
    ln -- "$source" "$target" 2>/dev/null || cp -p -- "$source" "$target" || return 1
  fi
}

seed_rpm_cache() {
  local cache="$1" bundle="$2" section package
  [[ -d "$cache/drivers" && -d "$cache/os-deps" ]] \
    || { printf 'ERROR: --rpm-cache must contain drivers/ and os-deps/\n' >&2; return 1; }
  for section in drivers os-deps; do
    while IFS= read -r -d '' package; do
      place_rpm "$package" "$bundle/$section" || return 1
    done < <(find "$cache/$section" -maxdepth 1 -type f -name '*.rpm' -print0)
  done
}

classify_runtime_rpm() {
  local package="$1" nvidia_db="$2" os_db="$3" bundle="$4" wanted="$5" result
  verify_el8_rpm "$package" && verify_driver_only_rpm "$package" || return 1
  if result="$(LC_ALL=C rpm --dbpath "$nvidia_db" -K "$package" 2>&1)" && [[ "$result" == *"signatures OK"* ]]; then
    verify_pinned_nvidia_rpm "$package" "$wanted" && place_rpm "$package" "$bundle/drivers" || return 1
  elif result="$(LC_ALL=C rpm --dbpath "$os_db" -K "$package" 2>&1)" && [[ "$result" == *"signatures OK"* ]]; then
    place_rpm "$package" "$bundle/os-deps" || return 1
  else
    printf 'ERROR: runtime RPM is not signed by a pinned NVIDIA/Red Hat/EPEL trust key: %s\n' "$package" >&2
    return 1
  fi
}

verify_pinned_nvidia_rpm() {
  local package="$1" wanted="$2" name version
  IFS='|' read -r name version < <(rpm -qp --qf '%{NAME}|%{VERSION}\n' "$package")
  case "$name" in
    kmod-nvidia-open-dkms|libnvidia-cfg|libnvidia-fbc|libnvidia-gpucomp|libnvidia-ml|nvidia-driver|nvidia-driver-cuda|nvidia-driver-cuda-libs|nvidia-driver-libs|nvidia-kmod-common|nvidia-libXNVCtrl|nvidia-libXNVCtrl-devel|nvidia-modprobe|nvidia-persistenced|nvidia-settings|nvidia-xconfig|xorg-x11-nvidia)
      [[ "$version" == "$wanted" ]] \
        || { printf 'ERROR: NVIDIA driver family must remain pinned to %s: %s %s\n' "$wanted" "$name" "$version" >&2; return 1; } ;;
    dnf-plugin-nvidia|egl-gbm|egl-wayland|egl-wayland2|egl-x11|libvdpau) return 0 ;;
    *) printf 'ERROR: unexpected NVIDIA package outside reviewed driver/support set: %s\n' "$name" >&2; return 1 ;;
  esac
}

offline_preview_passed() {
  grep -Fxq 'Transaction Summary' "$1" && grep -Fq 'Operation aborted.' "$1"
}

# GNU version sorting puts the GA '.el8_10' suffix after numeric patch fields.
# Sort the kernel's numeric update components explicitly, keeping GA first.
sort_stock_kernels() {
  local kernel update
  while IFS= read -r kernel; do
    valid_target_kernel "$kernel" || continue
    update="${kernel#4.18.0-553}"
    if [[ "$update" == .el8_10.x86_64 ]]; then
      printf '0\t0\t0\t%s\n' "$kernel"
    else
      update="${update#.}"
      update="${update%.el8_10.x86_64}"
      printf '1\t%s\t%s\t%s\n' "${update%%.*}" "${update#*.}" "$kernel"
    fi
  done | sort -t $'\t' -k1,1n -k2,2n -k3,3n -k4,4 | cut -f4 | uniq
}
