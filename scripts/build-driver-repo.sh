#!/usr/bin/env bash
# Stage NVIDIA R580 Open-DKMS plus build dependencies for one or many RHEL 8.10
# GPU-server kernels. NVIDIA RPMs come from NVIDIA's public RHEL 8.10 repository.
# The exact Red Hat kernel-devel RPM and its build dependencies are downloaded
# from the staging host's entitled RHEL/EPEL repositories into a second local
# repository. Subscription-controlled RPMs are output artifacts and must never
# be committed to this public source repository.

set -Eeuo pipefail
shopt -s nullglob

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly NVIDIA_BASE_URL="https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64"
readonly STATUS_URL="${NVIDIA_BASE_URL}/precompiled/"
readonly NVIDIA_KEY_FINGERPRINT="610C7B14E068A878070DA4E99CD0A493D42D0685"
readonly MODULE_STREAM="580-open"
readonly DEFAULT_DRIVER_VERSION="580.196.07"

AS_OF="$(date +%F)"
WINDOW_DAYS=365
OUTPUT_DIR="${SCRIPT_DIR}/../dist/nvidia-r580-rhel8-driver-repo-${AS_OF//-/}"
TARGET_KERNEL=""
ALL_KERNELS=0
TARGET_KERNELS=()
DRIVER_VERSION="$DEFAULT_DRIVER_VERSION"
DRY_RUN=0
METADATA_ONLY=0
RESUME=0
RPM_CACHE=""
SOURCE_REPO_IDS=()
MAKE_ISO=1
STATUS_SOURCE=""
INDEX_SOURCE=""
MODULES_SOURCE=""
LOG_FILE=""

usage() {
  cat <<'EOF'
Usage: ./build-driver-repo.sh [options]

Builds a driver-and-build-dependency DNF bundle for an air-gapped repo
server. The output contains the exact NVIDIA R580 Open-DKMS driver set and
RHEL/EPEL build dependencies for selected kernels, plus the resolved runtime
dependency closure. No CUDA Toolkit is included.

Options:
  --output DIR          Output directory under dist/
  --target-kernel NVR   One exact RHEL 8.10 kernel (mutually exclusive with --all-kernels)
  --all-kernels         Bundle every available stock RHEL 8.10 kernel-devel/header pair
  --driver-version VER  Exact R580 version (default: 580.196.07)
  --as-of YYYY-MM-DD    End of the coverage window (default: today)
  --window-days N       Coverage window (default: 365)
  --status-html FILE    Saved NVIDIA precompiled status page (test/replay)
  --repo-index FILE     Saved NVIDIA RHEL 8.10 repository index (test/replay)
  --modules-yaml FILE   Saved upstream modules.yaml[.gz] (test/replay)
  --no-iso              Produce the repository directory/tar only
  --resume              Reuse an incomplete output only; rerun all verification
  --rpm-cache DIR       Reuse only RPMs from a prior bundle in a fresh output
  --source-repoid ID    RHEL/EPEL source repo for closure resolution; repeat as needed
  --dry-run             Check NVIDIA metadata and entitled DNF dependencies; download no RPMs
  --metadata-only       Check NVIDIA selection only; no kernel, DNF or RPM tool required
  --log FILE            Log path (default: OUTPUT/build.log)
  -h, --help            Show help

Exit 42: the exact driver or kernel-devel package is unavailable.
EOF
}

while (($#)); do
  case "$1" in
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --target-kernel) TARGET_KERNEL="$2"; shift 2 ;;
    --all-kernels) ALL_KERNELS=1; shift ;;
    --driver-version) DRIVER_VERSION="$2"; shift 2 ;;
    --as-of) AS_OF="$2"; shift 2 ;;
    --window-days) WINDOW_DAYS="$2"; shift 2 ;;
    --status-html) STATUS_SOURCE="$2"; shift 2 ;;
    --repo-index) INDEX_SOURCE="$2"; shift 2 ;;
    --modules-yaml) MODULES_SOURCE="$2"; shift 2 ;;
    --no-iso) MAKE_ISO=0; shift ;;
    --resume) RESUME=1; shift ;;
    --rpm-cache) RPM_CACHE="$2"; shift 2 ;;
    --source-repoid) SOURCE_REPO_IDS+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --metadata-only) METADATA_ONLY=1; shift ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$AS_OF" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { printf 'ERROR: invalid --as-of\n' >&2; exit 2; }
[[ "$WINDOW_DAYS" =~ ^[0-9]+$ ]] && ((WINDOW_DAYS > 0)) || { printf 'ERROR: invalid --window-days\n' >&2; exit 2; }
. "$SCRIPT_DIR/rhel8-common.sh"
if ((ALL_KERNELS)) && [[ -n "$TARGET_KERNEL" ]]; then
  printf 'ERROR: select --all-kernels OR --target-kernel, not both\n' >&2
  exit 2
fi
if [[ -n "$TARGET_KERNEL" ]]; then
  valid_target_kernel "$TARGET_KERNEL" || { printf 'ERROR: --target-kernel must be an exact stock RHEL 8.10 4.18.0-553[.N.N].el8_10.x86_64 kernel\n' >&2; exit 2; }
elif ((METADATA_ONLY == 0 && ALL_KERNELS == 0)); then
  printf 'ERROR: --all-kernels or --target-kernel is required. Use --metadata-only for NVIDIA-only checks.\n' >&2
  exit 2
fi
[[ "$DRIVER_VERSION" =~ ^580\.[0-9]+\.[0-9]+$ ]] \
  || { printf 'ERROR: --driver-version must be an R580 version\n' >&2; exit 2; }

timestamp() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s] %s\n' "$(timestamp)" "$*"; }
die() { log "ERROR: $*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"; }

for cmd in bash curl awk grep sort sha256sum gzip gpg; do need "$cmd"; done
# RHEL 8 system Python 3.6 cannot execute this parser. Never replace that interpreter.
if [[ -z "${PYTHON_BIN:-}" ]]; then
  for candidate in python3.9 python3.11 python3.13 python3; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' 2>/dev/null; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi
[[ -n "${PYTHON_BIN:-}" ]] && "$PYTHON_BIN" -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' \
  || die "Python 3.9+ is required. Set PYTHON_BIN=/path/to/python3.9; do not replace RHEL 8 system Python."
if ((METADATA_ONLY == 0)); then require_rhel810_host; fi
if ((!DRY_RUN && !METADATA_ONLY)); then
  for cmd in rpm dnf createrepo_c modifyrepo_c tar cmp ln cp; do need "$cmd"; done
  dnf download --help >/dev/null 2>&1 \
    || die "dnf download is unavailable; install dnf-plugins-core on the staging host"
  if ((MAKE_ISO)); then need xorriso; fi
fi

if ((DRY_RUN || METADATA_ONLY)); then
  WORK_ROOT="$(mktemp -d -t nvidia-driver-repo.XXXXXXXX)"
  LOG_FILE="${LOG_FILE:-${WORK_ROOT}/build.log}"
else
  mkdir -p "$OUTPUT_DIR"
  WORK_ROOT="${OUTPUT_DIR}/work"
  LOG_FILE="${LOG_FILE:-${OUTPUT_DIR}/build.log}"
fi
mkdir -p "$WORK_ROOT/sources" "$(dirname -- "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

SOURCE_DIR="${WORK_ROOT}/sources"
STATUS_HTML="${SOURCE_DIR}/precompiled.html"
REPO_INDEX="${SOURCE_DIR}/repo-index.html"
REPOMD="${SOURCE_DIR}/repomd.xml"
MODULES_YAML="${SOURCE_DIR}/modules.yaml"
NVIDIA_KEY="${SOURCE_DIR}/D42D0685.pub"
RPM_LIST="${WORK_ROOT}/repo-rpms.txt"
COVERAGE_TSV="${WORK_ROOT}/coverage.tsv"
DKMS_TSV="${WORK_ROOT}/dkms-selected.tsv"

fetch_or_copy() {
  local source="$1" url="$2" destination="$3"
  if [[ -n "$source" ]]; then
    [[ -r "$source" ]] || die "cannot read source: $source"
    if [[ "$source" == *.gz ]]; then gzip -dc -- "$source" > "$destination"; else cp -f -- "$source" "$destination"; fi
  else
    curl --fail --location --silent --show-error --retry 4 "$url" -o "$destination"
  fi
}

log "Reading NVIDIA's RHEL 8.10 repository and precompiled-kmod status"
fetch_or_copy "$STATUS_SOURCE" "$STATUS_URL" "$STATUS_HTML"
fetch_or_copy "$INDEX_SOURCE" "${NVIDIA_BASE_URL}/" "$REPO_INDEX"

if [[ -n "$MODULES_SOURCE" ]]; then
  fetch_or_copy "$MODULES_SOURCE" "" "$MODULES_YAML"
else
  fetch_or_copy "" "${NVIDIA_BASE_URL}/repodata/repomd.xml" "$REPOMD"
  modules_href="$("$PYTHON_BIN" - "$REPOMD" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
ns = {'r': 'http://linux.duke.edu/metadata/repo'}
for data in root.findall('r:data', ns):
    if data.get('type') == 'modules':
        print(data.find('r:location', ns).get('href'))
        break
else:
    raise SystemExit('modules metadata not present')
PY
)"
  module_blob="${SOURCE_DIR}/modules.blob"
  fetch_or_copy "" "${NVIDIA_BASE_URL}/${modules_href}" "$module_blob"
  gzip -dc -- "$module_blob" > "$MODULES_YAML"
fi

fetch_or_copy "" "${NVIDIA_BASE_URL}/D42D0685.pub" "$NVIDIA_KEY"
observed_fingerprint="$(gpg --show-keys --with-colons --fingerprint "$NVIDIA_KEY" 2>/dev/null | awk -F: '$1=="fpr" {print toupper($10); exit}')"
[[ "$observed_fingerprint" == "$NVIDIA_KEY_FINGERPRINT" ]] \
  || die "NVIDIA signing-key fingerprint mismatch: ${observed_fingerprint:-none}"

"$PYTHON_BIN" "$SCRIPT_DIR/parse_sources.py" list-rpms --repo-index "$REPO_INDEX" > "$RPM_LIST"
"$PYTHON_BIN" "$SCRIPT_DIR/parse_sources.py" module-streams --modules "$MODULES_YAML" | grep -Fxq "$MODULE_STREAM" \
  || die "module metadata does not contain ${MODULE_STREAM}"

latest_rpm_for() {
  local name="$1" version="$2" arch="$3"
  grep -E "^${name}-${version//./\\.}-[^/]*\.el8(_[0-9]+)?\.${arch}\.rpm$" "$RPM_LIST" | sort -V | tail -n 1
}

userspace_names=(
  libnvidia-cfg libnvidia-fbc libnvidia-gpucomp libnvidia-ml nvidia-driver
  nvidia-driver-cuda nvidia-driver-cuda-libs nvidia-driver-libs
  nvidia-kmod-common nvidia-libXNVCtrl nvidia-libXNVCtrl-devel
  nvidia-modprobe nvidia-persistenced nvidia-settings nvidia-xconfig
  xorg-x11-nvidia
)

set +e
"$PYTHON_BIN" "$SCRIPT_DIR/parse_sources.py" coverage \
  --status-html "$STATUS_HTML" --repo-index "$REPO_INDEX" \
  --as-of "$AS_OF" --days "$WINDOW_DAYS" --require-covered > "$COVERAGE_TSV"
coverage_rc=$?
set -e
((coverage_rc == 0 || coverage_rc == 42)) || die "coverage parser failed (${coverage_rc})"

covered_count="$(awk -F '\t' '$3=="COVERED" {n++} END {print n+0}' "$COVERAGE_TSV")"
gap_count="$(awk -F '\t' '$3=="GAP" {n++} END {print n+0}' "$COVERAGE_TSV")"
log "Last-${WINDOW_DAYS}-day coverage: ${covered_count} covered, ${gap_count} gaps"

set +e
"$PYTHON_BIN" "$SCRIPT_DIR/parse_sources.py" dkms-fallbacks \
  --repo-index "$REPO_INDEX" --driver-version "$DRIVER_VERSION" \
  --require-all > "$DKMS_TSV"
dkms_rc=$?
set -e
((dkms_rc == 0 || dkms_rc == 42)) || die "open-DKMS selection failed (${dkms_rc})"

dkms_count="$(awk -F '\t' '$1 != "driver_version" && $2=="AVAILABLE" {n++} END {print n+0}' "$DKMS_TSV")"
log "Selected target kernel: ${TARGET_KERNEL}"
log "Selected R580 Open-DKMS version: ${DRIVER_VERSION}"

if ((covered_count == 0)); then
  log "NOTICE: no non-DKMS precompiled OPEN R580 kmod exists in the NVIDIA RHEL 8.10 repository."
  log "The bundle will contain signed open-DKMS emergency fallback sets; the target must opt in with --dkms-fallback."
fi

if ((dkms_count == 0)); then
  log "BLOCKED: exact R580 Open-DKMS ${DRIVER_VERSION} is unavailable."
  cat "$DKMS_TSV"
  if ((!DRY_RUN && !METADATA_ONLY)); then
    cp -f -- "$COVERAGE_TSV" "${OUTPUT_DIR}/COVERAGE.txt"
    cp -f -- "$DKMS_TSV" "${OUTPUT_DIR}/DKMS_SELECTED.txt"
  fi
  exit 42
fi

while IFS=$'\t' read -r driver status dkms_file reason; do
  [[ "$driver" == "driver_version" || "$status" != "AVAILABLE" ]] && continue
  for name in "${userspace_names[@]}"; do
    arch=x86_64
    [[ "$name" == nvidia-kmod-common ]] && arch=noarch
    [[ -n "$(latest_rpm_for "$name" "$driver" "$arch")" ]] \
      || die "repository index lacks matching userspace RPM: ${name} ${driver} ${arch}"
  done
done < "$DKMS_TSV"

selected_rpms="${WORK_ROOT}/selected-module-rpms.txt"
awk -F '\t' 'NR > 1 && $2 == "AVAILABLE" {print $3}' "$DKMS_TSV" > "$selected_rpms"
for name in "${userspace_names[@]}"; do
  arch=x86_64
  [[ "$name" == nvidia-kmod-common ]] && arch=noarch
  latest_rpm_for "$name" "$DRIVER_VERSION" "$arch" >> "$selected_rpms"
done
"$PYTHON_BIN" "$SCRIPT_DIR/parse_sources.py" verify-module-rpms \
  --modules "$MODULES_YAML" --stream "$MODULE_STREAM" --rpms-file "$selected_rpms" \
  || { log "BLOCKED: exact driver set is not selectable through upstream $MODULE_STREAM module metadata"; exit 42; }

plugin="$(grep -E '^dnf-plugin-nvidia-.*\.el8(_[0-9]+)?\.noarch\.rpm$' "$RPM_LIST" | sort -V | tail -n 1)"
[[ -n "$plugin" ]] || die "dnf-plugin-nvidia missing from upstream repository"

if ((METADATA_ONLY)); then
  cat "$DKMS_TSV"
  for name in "${userspace_names[@]}"; do
    arch=x86_64
    [[ "$name" == nvidia-kmod-common ]] && arch=noarch
    latest_rpm_for "$name" "$DRIVER_VERSION" "$arch"
  done
  printf '%s\n' "$plugin"
  log "Metadata-only passed: exact EL8 open-DKMS, 16 matching userspace RPMs and plugin found."
  log "This proves selection only; RPM signatures, dependency closure, DKMS build and GPU operation are unverified."
  exit 0
fi

need dnf
if ((ALL_KERNELS)); then
  kernel_query="$(dnf -q --showduplicates repoquery --available --qf '%{version}-%{release}.%{arch}' kernel-devel)" \
    || die "failed to query entitled RHEL kernel-devel packages"
  while IFS= read -r candidate_kernel; do
    if valid_target_kernel "$candidate_kernel"; then TARGET_KERNELS+=("$candidate_kernel"); fi
  done < <(printf '%s\n' "$kernel_query" | sort_stock_kernels)
  ((${#TARGET_KERNELS[@]} > 0)) \
    || { log "BLOCKED: no stock RHEL 8.10 kernel-devel packages are visible"; exit 42; }
else
  TARGET_KERNELS=("$TARGET_KERNEL")
fi
log "Selected ${#TARGET_KERNELS[@]} stock RHEL 8.10 kernels"
printf '  %s\n' "${TARGET_KERNELS[@]}"
os_dependency_specs=(gcc gcc-c++ make python36 dkms elfutils-libelf-devel python3-dnf-plugin-versionlock mokutil pciutils)
for selected_kernel in "${TARGET_KERNELS[@]}"; do
  os_dependency_specs+=("kernel-devel-${selected_kernel}" "kernel-headers-${selected_kernel}")
done
# Query every requested package once; verify each exact kernel pair against the
# returned identities instead of paying one DNF startup per requested package.
available_dependencies="$(dnf -q repoquery --available --qf '%{name}|%{version}-%{release}.%{arch}' "${os_dependency_specs[@]}")" \
  || die "failed to query the selected RHEL/EPEL package identities"
for required in "${os_dependency_specs[@]}"; do
  case "$required" in
    kernel-devel-*) required_identity="kernel-devel|${required#kernel-devel-}" ;;
    kernel-headers-*) required_identity="kernel-headers|${required#kernel-headers-}" ;;
    *) required_identity="" ;;
  esac
  if [[ -n "$required_identity" ]]; then
    grep -Fxq "$required_identity" <<< "$available_dependencies" \
      || { log "BLOCKED: required RHEL/EPEL package is unavailable: ${required}"; exit 42; }
  else
    awk -F '|' -v wanted="$required" '$1 == wanted {found=1} END {exit !found}' <<< "$available_dependencies" \
      || { log "BLOCKED: required RHEL/EPEL package is unavailable: ${required}"; exit 42; }
  fi
done
if ((DRY_RUN)); then
  log "Entitled RHEL/EPEL repositories expose every selected kernel pair and shared build prerequisites."
  log "Dry-run passed. No RPMs or repository artifacts were written."
  exit 0
fi

REPO_ROOT="${OUTPUT_DIR}/repo-bundle"
check_bundle_output "$REPO_ROOT" "$RESUME" || exit 1
if ((RESUME)); then log "Resuming incomplete payload; metadata, identities, and every RPM signature will be checked again."; fi
DRIVERS_DIR="${REPO_ROOT}/drivers"
OS_DEPS_DIR="${REPO_ROOT}/os-deps"
mkdir -p "$DRIVERS_DIR" "$OS_DEPS_DIR" "${REPO_ROOT}/docs"
if [[ -n "$RPM_CACHE" ]]; then
  ((RESUME == 0)) || die "use --rpm-cache with a fresh output; do not combine it with --resume"
  seed_rpm_cache "$RPM_CACHE" "$REPO_ROOT" || die "RPM-only cache import failed"
  log "Seeded RPM cache only; vendor signatures will be checked again."
fi

log "Downloading exact RHEL/EPEL build dependencies for ${#TARGET_KERNELS[@]} kernels"
if ! dnf -y download --resolve --alldeps --archlist=x86_64,noarch \
  --destdir "$OS_DEPS_DIR" "${os_dependency_specs[@]}"; then
  log "BLOCKED: the staging host's enabled entitled RHEL/EPEL repositories do not provide the complete dependency set."
  log "Required kernel pairs: ${TARGET_KERNELS[*]}"
  log "Enable the matching RHEL BaseOS/AppStream and EPEL repositories, then rerun."
  exit 42
fi

printf '%s\n' "${TARGET_KERNELS[@]}" > "${REPO_ROOT}/SUPPORTED_KERNELS.txt"
printf 'target_kernel\tpackage\n' > "${REPO_ROOT}/OS_DEPENDENCIES.tsv"
for selected_kernel in "${TARGET_KERNELS[@]}"; do
  for package_name in kernel-devel kernel-headers; do
    matched_package="$OS_DEPS_DIR/${package_name}-${selected_kernel}.rpm"
    [[ -s "$matched_package" ]] \
      || { log "BLOCKED: downloaded payload lacks ${package_name}-${selected_kernel}"; exit 42; }
    package_identity="$(rpm -qp --qf '%{NAME}|%{VERSION}-%{RELEASE}.%{ARCH}' "$matched_package")"
    [[ "$package_identity" == "${package_name}|${selected_kernel}" ]] \
      || { log "BLOCKED: downloaded RPM identity differs from ${package_name}-${selected_kernel}"; exit 42; }
    printf '%s\t%s\n' "$selected_kernel" "$(basename -- "$matched_package")" >> "${REPO_ROOT}/OS_DEPENDENCIES.tsv"
  done
done

download_rpm() {
  local filename="$1"
  [[ -s "${DRIVERS_DIR}/${filename}" ]] && return 0
  curl --fail --location --show-error --retry 4 --continue-at - \
    "${NVIDIA_BASE_URL}/${filename}" -o "${DRIVERS_DIR}/${filename}"
}

download_userspace_set() {
  local driver="$1" name arch filename
  for name in "${userspace_names[@]}"; do
    arch=x86_64
    [[ "$name" == nvidia-kmod-common ]] && arch=noarch
    filename="$(latest_rpm_for "$name" "$driver" "$arch")"
    [[ -n "$filename" ]] || die "missing exact userspace RPM: ${name} ${driver} ${arch}"
    download_rpm "$filename"
  done
}

printf 'kernel\tdriver_version\tpackage_files_semicolon_separated\n' > "${REPO_ROOT}/DRIVER_SETS.tsv"
printf 'driver_version\topen_dkms_rpm\tpackage_files_semicolon_separated\n' > "${REPO_ROOT}/DKMS_FALLBACK_SETS.tsv"
while IFS=$'\t' read -r driver status dkms_file reason; do
  [[ "$driver" == "driver_version" || "$status" != "AVAILABLE" ]] && continue
  download_rpm "$dkms_file"
  verify_open_dkms "${DRIVERS_DIR}/${dkms_file}" "$driver" \
    || die "candidate is not a verified R580 open-DKMS package: $dkms_file"
  download_userspace_set "$driver"
  files="$(find "$DRIVERS_DIR" -maxdepth 1 -type f -name "*${driver}*.rpm" -printf '%f\n' | sort -V | paste -sd';' -)"
  printf '%s\t%s\t%s\n' "$driver" "$dkms_file" "$files" >> "${REPO_ROOT}/DKMS_FALLBACK_SETS.tsv"
done < "$DKMS_TSV"

download_rpm "$plugin"

# Signature databases are private staging resources, never system RPM trust.
redhat_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
epel_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
[[ -r "$redhat_key" && -r "$epel_key" ]] || die "Red Hat/EPEL 8 public RPM keys are unavailable"
verify_db="$(mktemp -d -t nvidia-stage-rpmdb.XXXXXXXX)"
os_verify_db="$(mktemp -d -t os-deps-stage-rpmdb.XXXXXXXX)"
trap 'rm -rf -- "$verify_db" "$os_verify_db"' EXIT
rpm --dbpath "$verify_db" --initdb
rpm --dbpath "$verify_db" --import "$NVIDIA_KEY"
rpm --dbpath "$os_verify_db" --initdb
rpm --dbpath "$os_verify_db" --import "$redhat_key" "$epel_key"

# A fresh installroot resolves the driver and runtime closure independently of
# installed staging-host packages or its NVIDIA module-stream state. Kernel
# pairs are already cached above and are deliberately excluded from this second
# download to avoid duplicating the multi-gigabyte broad-kernel payload.
if ((${#SOURCE_REPO_IDS[@]} == 0)); then
  SOURCE_REPO_IDS=(rhel-8-for-x86_64-baseos-rpms rhel-8-for-x86_64-appstream-rpms codeready-builder-for-rhel-8-x86_64-rpms epel)
fi
runtime_dnf=(dnf -y --installroot="${WORK_ROOT}/runtime-resolver-root" --config=/etc/dnf/dnf.conf
  --releasever=8.10 --setopt=reposdir=/etc/yum.repos.d --setopt=module_platform_id=platform:el8
  --disableplugin=subscription-manager,nvidia --setopt=exclude= --disablerepo='*')
for source_repoid in "${SOURCE_REPO_IDS[@]}"; do
  [[ "$source_repoid" =~ ^[a-zA-Z0-9_.:-]+$ ]] || die "--source-repoid requires a literal repo ID"
  runtime_dnf+=(--enablerepo="$source_repoid")
done
runtime_dnf+=(--repofrompath="nvidia-r580-rhel8-build,${NVIDIA_BASE_URL}/" --enablerepo=nvidia-r580-rhel8-build
  --setopt=nvidia-r580-rhel8-build.module_hotfixes=true)
runtime_specs=(gcc gcc-c++ make dkms elfutils-libelf-devel python36 /usr/bin/python3.6 python3-dnf-plugin-versionlock mokutil pciutils)
while IFS= read -r filename; do runtime_specs+=("${filename%.rpm}"); done < "$selected_rpms"
runtime_specs+=("${plugin%.rpm}")
# dnf download resolves roots independently. Restrict this ephemeral source to
# the exact pinned profile and reviewed independent EGL support packages so a
# root's >= dependency cannot silently pull a newer NVIDIA driver branch.
allowed_nvidia=("${plugin%.rpm}" egl-gbm egl-wayland egl-wayland2 egl-x11 libvdpau)
while IFS= read -r filename; do allowed_nvidia+=("${filename%.rpm}"); done < "$selected_rpms"
allowed_nvidia_csv="$(IFS=,; printf '%s' "${allowed_nvidia[*]}")"
runtime_dnf+=(--setopt="nvidia-r580-rhel8-build.includepkgs=${allowed_nvidia_csv}")
runtime_dir="${WORK_ROOT}/runtime-download"
mkdir -p "$runtime_dir"
log "Resolving the complete driver/runtime/build closure in a fresh RHEL 8.10 installroot"
"${runtime_dnf[@]}" download --resolve --alldeps --archlist=x86_64,noarch --destdir="$runtime_dir" "${runtime_specs[@]}" \
  || die "full driver/runtime dependency closure could not be resolved from approved source repositories"
(($(find "$runtime_dir" -maxdepth 1 -type f -name '*.rpm' | wc -l) > 0)) || die "runtime closure produced no RPMs"
printf 'package_file\trepository\n' > "${REPO_ROOT}/RUNTIME_DEPENDENCIES.tsv"
for package in "$runtime_dir"/*.rpm; do
  classify_runtime_rpm "$package" "$verify_db" "$os_verify_db" "$REPO_ROOT" "$DRIVER_VERSION" \
    || die "runtime RPM identity, pinned version, driver-only policy, signature, or cached-file parity check failed"
  repository=os-deps
  [[ ! -f "$DRIVERS_DIR/$(basename -- "$package")" ]] || repository=drivers
  printf '%s\t%s\n' "$(basename -- "$package")" "$repository" >> "${REPO_ROOT}/RUNTIME_DEPENDENCIES.tsv"
done
# Classification links/copies only verified RPMs into their vendor repository.
rm -rf -- "$runtime_dir"

log "Checking every EL8 RPM identity, driver-only policy, and vendor signature before repository creation"
for package in "$DRIVERS_DIR"/*.rpm "$OS_DEPS_DIR"/*.rpm; do
  verify_el8_rpm "$package" && verify_driver_only_rpm "$package" \
    || die "payload contains an unsupported or toolkit RPM: $package"
done
while IFS= read -r -d '' package; do
  verify_pinned_nvidia_rpm "$package" "$DRIVER_VERSION" || die "NVIDIA payload contains an unexpected family or driver version"
  result="$(LC_ALL=C rpm --dbpath "$verify_db" -K "$package")"
  printf '%s\n' "$result"
  [[ "$result" == *"signatures OK"* ]] || die "NVIDIA RPM signature verification failed: $package"
done < <(find "$DRIVERS_DIR" -maxdepth 1 -type f -name '*.rpm' -print0)
while IFS= read -r -d '' package; do
  result="$(LC_ALL=C rpm --dbpath "$os_verify_db" -K "$package")"
  printf '%s\n' "$result"
  [[ "$result" == *"signatures OK"* ]] || die "Red Hat/EPEL RPM signature verification failed: $package"
done < <(find "$OS_DEPS_DIR" -maxdepth 1 -type f -name '*.rpm' -print0)

createrepo_c --update --database "$DRIVERS_DIR"
cp -f -- "$MODULES_YAML" "${DRIVERS_DIR}/modules.yaml"
modifyrepo_c --mdtype=modules "${DRIVERS_DIR}/modules.yaml" "${DRIVERS_DIR}/repodata/"
createrepo_c --update --database "$OS_DEPS_DIR"

# Prove a fresh machine can solve the installation using these two file repos
# only. --assumeno produces a transaction preview and writes no installed RPMs.
preview_root="${WORK_ROOT}/offline-validation-root"
preview_repos="${WORK_ROOT}/offline-empty-repos"
mkdir -p "$preview_repos"
offline_dnf=(dnf --installroot="$preview_root" --config=/etc/dnf/dnf.conf --releasever=8.10
  --setopt="reposdir=$preview_repos" --setopt=module_platform_id=platform:el8
  --disableplugin=subscription-manager,nvidia --disableexcludes=all --disablerepo='*'
  --repofrompath="offline-nvidia,file://$DRIVERS_DIR" --enablerepo=offline-nvidia
  --repofrompath="offline-os-deps,file://$OS_DEPS_DIR" --enablerepo=offline-os-deps
  --setopt=offline-nvidia.gpgcheck=0 --setopt=offline-os-deps.gpgcheck=0
  --setopt=offline-os-deps.module_hotfixes=true)
LC_ALL=C "${offline_dnf[@]}" -y module enable "nvidia-driver:$MODULE_STREAM" \
  || die "paired offline repositories cannot enable the NVIDIA module stream"
preview_specs=(gcc gcc-c++ make dkms elfutils-libelf-devel python36 python3-dnf-plugin-versionlock mokutil pciutils)
while IFS= read -r filename; do preview_specs+=("${filename%.rpm}"); done < "$selected_rpms"
preview_specs+=("${plugin%.rpm}")
last_kernel="${TARGET_KERNELS[${#TARGET_KERNELS[@]}-1]}"
preview_specs+=("kernel-devel-$last_kernel" "kernel-headers-$last_kernel")
preview_log="${REPO_ROOT}/OFFLINE_INSTALL_PREVIEW.txt"
set +e
LC_ALL=C "${offline_dnf[@]}" --assumeno install "${preview_specs[@]}" > "$preview_log" 2>&1
preview_rc=$?
set -e
if ! offline_preview_passed "$preview_log"; then
  cat "$preview_log"
  die "paired-only offline installation preview did not resolve (DNF exit $preview_rc)"
fi
log "Paired-only offline installation dependency preview passed for kernel $last_kernel; no RPM was installed."

cp -f -- "$NVIDIA_KEY" "${REPO_ROOT}/NVIDIA-GPG-KEY-D42D0685.pub"
mkdir -p "${REPO_ROOT}/keys"
cp -f -- "$redhat_key" "$epel_key" "${REPO_ROOT}/keys/"
cp -f -- "$COVERAGE_TSV" "${REPO_ROOT}/COVERAGE.txt"
cp -f -- "$SCRIPT_DIR/repo-server-import.sh" "$REPO_ROOT/"
cp -f -- "$SCRIPT_DIR/client-install.sh" "$REPO_ROOT/"
cp -f -- "$SCRIPT_DIR/rhel8-common.sh" "$REPO_ROOT/"
cp -f -- "$SCRIPT_DIR/../README.md" "$REPO_ROOT/README.md"
cp -f -- "$SCRIPT_DIR/../LICENSE" "$REPO_ROOT/LICENSE"
cp -f -- "$SCRIPT_DIR/../docs/INSTALL.md" "${REPO_ROOT}/docs/INSTALL.md"
cp -f -- "$SCRIPT_DIR/../docs/ON-SITE-QUICKSTART.md" "${REPO_ROOT}/docs/ON-SITE-QUICKSTART.md"
cp -f -- "$SCRIPT_DIR/../docs/LLM-CONTEXT.md" "${REPO_ROOT}/docs/LLM-CONTEXT.md"
cp -f -- "$SCRIPT_DIR/../PACKAGE-MANIFEST.md" "$REPO_ROOT/"
cp -f -- "$SCRIPT_DIR/../config/nvidia-r580-internal.repo.example" "$REPO_ROOT/"

{
  printf 'Target OS: RHEL 8.10 x86_64\n'
  printf 'Built UTC: %s\n' "$(timestamp)"
  printf 'Coverage window: %s days ending %s\n' "$WINDOW_DAYS" "$AS_OF"
  printf 'Module stream: %s\n' "$MODULE_STREAM"
  printf 'Supported kernel count: %s\n' "${#TARGET_KERNELS[@]}"
  printf 'Supported kernels: see SUPPORTED_KERNELS.txt\n'
  printf 'Selected driver version: %s\n' "$DRIVER_VERSION"
  printf 'Precompiled-open covered kernels: %s\n' "$covered_count"
  printf 'Precompiled-open GAP kernels: %s\n' "$gap_count"
  printf 'Runtime dependencies: included and verified by paired-only fresh-installroot transaction preview (see OFFLINE_INSTALL_PREVIEW.txt and RUNTIME_DEPENDENCIES.tsv)\n'
  printf 'Open-DKMS driver sets: %s\n' "$dkms_count"
  printf 'Repository path after import: set by the repo-server operator\n'
  printf 'NVIDIA RPM count: %s\n' "$(find "$DRIVERS_DIR" -type f -name '*.rpm' | wc -l)"
  printf 'RHEL/EPEL dependency RPM count: %s\n' "$(find "$OS_DEPS_DIR" -type f -name '*.rpm' | wc -l)"
  printf '\nNVIDIA packages:\n'
  find "$DRIVERS_DIR" -maxdepth 1 -type f -name '*.rpm' -printf '%f\n' | sort -V
  printf '\nRHEL/EPEL dependency packages:\n'
  find "$OS_DEPS_DIR" -maxdepth 1 -type f -name '*.rpm' -printf '%f\n' | sort -V
} > "${REPO_ROOT}/MANIFEST.txt"

(
  cd "$REPO_ROOT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

tar --sort=name --mtime="${AS_OF} 00:00:00 UTC" --owner=0 --group=0 --numeric-owner \
  -C "$OUTPUT_DIR" -czf "${OUTPUT_DIR}/nvidia-r580-rhel8-driver-repo-${AS_OF//-/}.tar.gz" repo-bundle
(
  cd "$OUTPUT_DIR"
  archive_name="nvidia-r580-rhel8-driver-repo-${AS_OF//-/}.tar.gz"
  sha256sum "$archive_name" > "$archive_name.sha256"
)

if ((MAKE_ISO)); then
  xorriso -as mkisofs -quiet -iso-level 3 -R -J -joliet-long \
    -V "NVR580_EL8_${AS_OF//-/}" -o "${OUTPUT_DIR}/nvidia-r580-rhel8-${AS_OF//-/}-vol1.iso" "$REPO_ROOT"
  (
    cd "$OUTPUT_DIR"
    iso_name="nvidia-r580-rhel8-${AS_OF//-/}-vol1.iso"
    sha256sum "$iso_name" > "$iso_name.sha256"
  )
fi

log "SUCCESS: repo bundle ready at ${REPO_ROOT}"
