# RHEL 8.10 NVIDIA R580 installation and air-gap transfer

## 1. Scope and current state

This procedure prepares an offline DNF repository for **RHEL 8.10 x86_64** and
NVIDIA RTX PRO 6000 Blackwell GPUs. The selected default driver is R580
`580.196.07`, using open kernel modules built through DKMS. Six GPUs are carried
forward from the prior deployment as an assumption; confirm the actual count
and exact hardware edition on the target.

The target kernel is **not known**, and the operator has not yet seen the box.
Use `--all-kernels` to prepare as many available standard RHEL 8.10 kernel
development pairs as the enabled entitled sources expose. The generated
`SUPPORTED_KERNELS.txt` records that bounded coverage; it is not a promise to
support every historical, custom, or future kernel. The client detects its
running kernel by default and refuses a missing exact development package pair.
An optional `--kernel` asserts a previously recorded approved value.

For a smaller known-target build, use `--target-kernel` with the GPU target's
recorded `uname -r`. The staging host's kernel never identifies the GPU target.

This local port has no new published GitHub release or ready-built RHEL 8
payload. Validate each generated build using its actual manifest, signatures,
coverage list, and paired-repository transaction evidence. Target DKMS build
and post-reboot GPU validation remain pending. The RHEL 9 release's package
counts, kernel, and verification record do not apply.

NVIDIA's [R580 support matrix](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-105-08/index.html)
lists RTX PRO 6000 Blackwell **Server Edition** on RHEL 8.10. The
[EL8 package index](https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/)
contains the selected Open-DKMS RPM. Confirm the actual GPU edition and its
support documentation; this statement does not establish support for all
similarly named models or for an unconfirmed MATLAB/application release.

This source adaptation comes from `BenjaminSisko/nvidia-r580-rhel9-airgap`
commit `4d492b8`; the original repository remains unchanged. This separate
local sibling contains the EL8 port.

NVIDIA's [580.196.07 module guidance](https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/kernel_open.html)
requires open modules for Blackwell and later. Its [GPU list](https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/supportedchips.html)
includes RTX PRO 6000 Blackwell Workstation, Max-Q Workstation, and Server
editions. Confirm the target variant and OS support separately.

This procedure installs the driver only. CUDA Toolkit, cuDNN, TensorRT, MATLAB,
and other application runtimes require their own scope and compatibility checks.

## 2. Capture the actual target facts at the site

Broad staging can proceed before these facts are available. At the site,
on the GPU target, collect these read-only facts in the approved private
change record:

```bash
cat /etc/redhat-release
uname -m
uname -r
rpm -q kernel-core
lspci -nn -d 10de:
mokutil --sb-state
rpm -qa | grep -E '^(nvidia|libnvidia|kmod-nvidia|cuda)' | sort
```

Confirm RHEL 8.10 x86_64, record the exact intended running kernel, and identify
the GPUs by PCI ID and model/edition. `lspci` includes non-GPU NVIDIA functions;
do not treat its line count as the GPU count. Resolve an existing driver or
`.run` installation under the approved change process before installing over it.

Record the chosen kernel on this target shell:

```bash
TARGET_KERNEL="$(uname -r)"
printf '%s\n' "$TARGET_KERNEL"
```

Compare the recorded kernel with `SUPPORTED_KERNELS.txt` and query the exact
pair in the offline dependency repository before installation. The client also
checks exact package availability before changing the host. If the kernel is
missing, obtain its exact signed development pair through a new connected
build, or make a separate approved OS change to a listed kernel and repeat
these checks. Do not accept an approximate development package match. Retain
the existing approved OS rollback path.

If rebuilding for this one target later, use this recorded value at staging
with `--target-kernel`. Do not use staging `uname -r`.

## 3. Prepare a connected staging host

Use an entitled **RHEL 8.10 x86_64** staging host whose repositories match the
target baseline. Ensure access to:

- NVIDIA's public RHEL 8 x86_64 repository.
- Entitled RHEL 8 BaseOS and AppStream containing the exact kernel development
  packages.
- The RHEL 8 CodeReady Linux Builder content required by EPEL dependencies.
- EPEL 8 with DKMS and its dependencies, plus its verified public signing key.

Repository enablement and subscriptions follow the site's normal entitlement
process. Do not copy subscription certificates or CDN client keys into the
source, transport bundle, or air-gapped system. Do not mix EL9 packages or use
Rocky/Alma kernel development packages for a Red Hat target.

Install builder prerequisites:

```bash
sudo dnf install -y \
  curl createrepo_c dnf-plugins-core gnupg2 xorriso rpm-build python39
/usr/bin/python3.9 --version
```

The tooling requires Python 3.9+. Select `/usr/bin/python3.9` through
`PYTHON_BIN` without replacing RHEL's platform Python. The target client shell
script does not require Python 3.9. If ISO output is disabled with `--no-iso`,
`xorriso` is unnecessary.

For the broad build, the script discovers standard RHEL 8.10 kernel-devel
versions from enabled metadata and requires corresponding exact kernel-headers
packages. Ensure the entitled content view retains the versions you want to
carry. A repository exposing only the latest erratum limits the resulting
coverage; metadata discovery cannot restore archived versions it cannot see.

For an optional single-target build, set the value captured **on the GPU
target**, then verify both exact packages:

```bash
# Optional known-target path; do not derive this value on staging.
TARGET_KERNEL='PASTE_GPU_TARGET_UNAME_R_HERE'
dnf repoquery --available "kernel-devel-${TARGET_KERNEL}"
dnf repoquery --available "kernel-headers-${TARGET_KERNEL}"
```

If either is unavailable, obtain the exact entitled Red Hat package before
building for that target. Never substitute a similarly named package.

## 4. Check metadata, then package availability

Public metadata alone can be checked on a connected machine without DNF, RPM,
Red Hat entitlement, or a target kernel:

```bash
PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh --metadata-only
```

That mode checks NVIDIA sources and key identity. It does not download RPMs,
resolve RHEL dependencies, or prove target installation readiness.

On the entitled RHEL 8.10 staging host, inspect broad package availability:

```bash
sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels \
  --driver-version 580.196.07 \
  --dry-run
```

The dry-run checks selected NVIDIA packages, discovered exact kernel pairs,
and named prerequisites without downloading RPM payloads. It needs DNF and
entitled RHEL 8.10 sources. A passing result does not establish complete
transaction closure or target DKMS operation. For a known-target build, replace
`--all-kernels` with `--target-kernel "$TARGET_KERNEL"`.

## 5. Build the transport bundle

```bash
sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels \
  --driver-version 580.196.07 \
  --output "$PWD/dist/rhel8-build"
```

Use a clean output directory for each reviewed build. The build stops for
missing exact driver/kernel packages or failed verification. It preserves
upstream module metadata for `nvidia-driver:580-open`, verifies RPM signatures,
generates local repository metadata, then creates transport hashes and media.
No client installation or repository-service publication happens during build.

The bundle is at `dist/rhel8-build/repo-bundle/`:

```text
repo-bundle/
├── drivers/                       EL8 NVIDIA DNF repository
├── os-deps/                       RHEL 8 / EPEL 8 dependency repository
├── keys/                          Public Red Hat and EPEL 8 RPM signing keys
├── NVIDIA-GPG-KEY-D42D0685.pub
├── COVERAGE.txt
├── DRIVER_SETS.tsv
├── DKMS_FALLBACK_SETS.tsv
├── OS_DEPENDENCIES.tsv
├── SUPPORTED_KERNELS.txt
├── MANIFEST.txt
├── SHA256SUMS
├── README.md
├── PACKAGE-MANIFEST.md
├── docs/
│   ├── INSTALL.md
│   └── LLM-CONTEXT.md
├── rhel8-common.sh
├── client-install.sh
├── repo-server-import.sh
└── nvidia-r580-internal.repo.example
```

The output directory also contains a tarball and, unless `--no-iso` is used,
an ISO with adjacent SHA-256 files. Use their actual generated filenames.
Check the actual ISO/tar size against the approved media's capacity. Broad
coverage may exceed a chosen disc size; do not assume a single DVD or BD-R
will fit. Any split-media process must preserve complete verified repositories
and hashes after reassembly.

Review:

```bash
BUNDLE="$PWD/dist/rhel8-build/repo-bundle"
less "$BUNDLE/MANIFEST.txt"
column -ts $'\t' "$BUNDLE/OS_DEPENDENCIES.tsv"
column -ts $'\t' "$BUNDLE/DKMS_FALLBACK_SETS.tsv"
(cd "$BUNDLE" && sha256sum -c SHA256SUMS)
```

Read `SUPPORTED_KERNELS.txt` and confirm each listed exact `kernel-devel` and
`kernel-headers` pair, EL8 Open-DKMS RPM, matching driver-versioned userspace,
public keys, and both repositories appear. Alternative development package
versions are carried for client selection; they are not all installed together.
The driver workflow does not provision kernel images.
NVIDIA's independently versioned DNF plugin is the exception to the driver
version equality rule. Do not accept `.el9` RPMs.

## 6. Prove offline transaction closure before transfer

A staging host can already contain libraries that hide missing offline
packages. The builder's prerequisite download and its availability dry-run do
not alone prove all NVIDIA userspace and toolchain dependencies are present.
Require the following acceptance test for the intended OS baseline and kernel
scope; inclusion in the coverage list proves package availability, not a DKMS
build on every listed kernel.

Use a clean, disposable RHEL 8.10 x86_64 VM or equivalent test system whose
baseline matches the GPU target. Verify and install the public keys through the
approved process, and configure only the generated `drivers/` and `os-deps/`
repositories. The following preview tests the full driver package set, with
one exact kernel pair at a time. It changes the module selection only on the
disposable test system; `--assumeno` then declines package installation after
resolution. Set the actual bundle path and one kernel from the coverage list:

```bash
BUNDLE='/absolute/path/to/repo-bundle'
TARGET_KERNEL='PASTE_ONE_EXACT_KERNEL_FROM_SUPPORTED_KERNELS'
DRIVER_VERSION=580.196.07

TEST_REPOS=(
  --disablerepo='*'
  --repofrompath="rhel8-driver-test,file://${BUNDLE}/drivers"
  --repofrompath="rhel8-deps-test,file://${BUNDLE}/os-deps"
  --enablerepo=rhel8-driver-test
  --enablerepo=rhel8-deps-test
  --setopt=rhel8-driver-test.gpgcheck=1
  --setopt=rhel8-deps-test.gpgcheck=1
)
sudo dnf "${TEST_REPOS[@]}" -y module enable nvidia-driver:580-open

DRIVER_NAMES=(
  kmod-nvidia-open-dkms libnvidia-cfg libnvidia-fbc libnvidia-gpucomp
  libnvidia-ml nvidia-driver nvidia-driver-cuda nvidia-driver-cuda-libs
  nvidia-driver-libs nvidia-kmod-common nvidia-libXNVCtrl
  nvidia-libXNVCtrl-devel nvidia-modprobe nvidia-persistenced
  nvidia-settings nvidia-xconfig xorg-x11-nvidia
)
SPECS=()
for package in "${DRIVER_NAMES[@]}"; do
  SPECS+=("${package}-${DRIVER_VERSION}*")
done
SPECS+=(dnf-plugin-nvidia "kernel-devel-${TARGET_KERNEL}"
  "kernel-headers-${TARGET_KERNEL}" gcc make dkms elfutils-libelf-devel
  python3-dnf-plugin-versionlock mokutil pciutils)

sudo dnf "${TEST_REPOS[@]}" --assumeno install "${SPECS[@]}"
```

An intentional `--assumeno` decline is expected after a complete transaction
preview; read the output instead of treating its nonzero exit as a resolver
failure. Confirm the transaction selected the exact intended driver and kernel
NEVRAs. Test included kernel pairs separately, since kernel-headers alternatives
are not installed together. Retain the full resolver evidence and baseline
package list. To exercise actual package scriptlets, run the equivalent
transaction on a disposable system booted to a selected matching kernel; a
preview alone cannot prove scriptlet or DKMS behavior.

The client installer itself requires NVIDIA PCI hardware, so a non-GPU VM
cannot pass its hardware guard. Use the full package-list transaction to test
that VM's repository closure; do not bypass production guards. Final DKMS,
Secure Boot loading, and GPU acceptance require the actual target hardware.

If anything is missing, obtain it from the matching entitled RHEL 8/EPEL 8
source, rebuild the bundle and metadata, repeat signatures/hashes, and retest.
Do not solve a missing dependency by allowing a third client repository or
assuming it is installed on every target. Record the clean baseline, exact
NEVRAs, repository restrictions, transaction output, and final bundle digest.
Final DKMS and GPU validation still require the actual target hardware.

## 7. Verify, burn, and transfer approved media

Check the tarball/ISO sidecar checksum from the directory containing it. Record
the approved digest outside the transport bundle. Burn and verify media using
the organization's approved transfer process before crossing the air gap.
`SHA256SUMS` detects changes relative to the approved digest; it does not by
itself authenticate a bundle whose contents and checksum files were replaced
together. Original RPM signatures remain mandatory.

## 8. Import on the offline repository server

The import host needs Bash, RPM, GnuPG, rsync, and SHA-256 tooling. Mount the ISO
at the site's approved mountpoint. From its root, retaining `rhel8-common.sh`
alongside the importer, run:

```bash
sudo ./repo-server-import.sh \
  --source /mnt/nvidia-media \
  --destination /srv/repos/nvidia-r580-rhel8
```

For a tarball, verify its sidecar checksum, extract it, and point `--source` at
the extracted `repo-bundle/` directory. The importer verifies bundle hashes,
NVIDIA's pinned public key, and vendor RPM signatures using the bundled public
keys in isolated RPM databases. It refuses a nonempty destination unless the
operator explicitly supplies `--allow-existing` after reviewing its contents.
Prefer a new versioned destination over an overlay that could retain old files.

Publish both directories through the existing approved repository service:

```text
/srv/repos/nvidia-r580-rhel8/drivers/
/srv/repos/nvidia-r580-rhel8/os-deps/
```

The example URL prefix is `/repos/nvidia-r580-rhel8/`. Web service, TLS, DNS,
firewall, SELinux, authentication, and publication changes follow the site's
normal process.

## 9. Configure client trust and repositories

Verify the public key provenance through approved vendor/site sources. Install
these keys through configuration management:

```text
/etc/pki/rpm-gpg/NVIDIA-GPG-KEY-D42D0685.pub
/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
```

Adapt `nvidia-r580-internal.repo.example` to the approved internal HTTPS URLs
and install it under `/etc/yum.repos.d/`. The two distinct IDs are:

```text
nvidia-r580-rhel8-internal
nvidia-r580-rhel8-os-deps
```

Keep `gpgcheck=1` and `sslverify=1`. Generated repository metadata is unsigned
(`repo_gpgcheck=0`); use approved authenticated transport, or implement the
site's required metadata-signing process before use. Do not enable
`module_hotfixes` as an unexplained workaround.

Verify both repositories and the selected stream:

```bash
dnf repolist --enabled
dnf --disablerepo='*' --enablerepo=nvidia-r580-rhel8-internal \
  module list nvidia-driver
```

## 10. Confirm coverage of the running kernel and handle Secure Boot

On the target, capture the actual running kernel and record it before install:

```bash
TARGET_KERNEL="$(uname -r)"
printf '%s\n' "$TARGET_KERNEL"
test -f "/boot/vmlinuz-${TARGET_KERNEL}"
grubby --default-kernel
mokutil --sb-state

dnf --disablerepo='*' --enablerepo=nvidia-r580-rhel8-os-deps \
  repoquery --available "kernel-devel-${TARGET_KERNEL}"
dnf --disablerepo='*' --enablerepo=nvidia-r580-rhel8-os-deps \
  repoquery --available "kernel-headers-${TARGET_KERNEL}"
```

Compare with the bundle's `SUPPORTED_KERNELS.txt`. If either exact package is
absent, stop before installation and rebuild for that kernel, or use a
separately approved OS procedure to install/boot a listed kernel. The driver
installer does not install a kernel image. Its default is the actual running
kernel; `--kernel` can additionally assert the recorded chosen value.

If Secure Boot is enabled, establish the approved DKMS module-signing and
trusted-key path before installation/reboot. These scripts do not create keys,
enroll a MOK, or change Secure Boot. A successful package transaction does not
prove a locally built module will load under Secure Boot.

## 11. Install the driver

Retain `rhel8-common.sh` alongside the bundled client installer. With the
covered target kernel running, the default command detects it automatically:

```bash
sudo ./client-install.sh --driver-version 580.196.07 \
  --expected-gpus 6 --dkms-fallback
```

For an additional assertion using the value captured in step 10:

```bash
sudo ./client-install.sh \
  --kernel "$TARGET_KERNEL" \
  --driver-version 580.196.07 \
  --expected-gpus 6 \
  --dkms-fallback
```

Confirm the expected count first; replace six if approved target evidence
differs. The explicit DKMS flag authorizes this script's toolchain path within
the approved change. The client checks OS/kernel, hardware and repositories,
selects matching open R580 packages, refuses a missing exact development pair
before mutation, installs prerequisites, checks exact `kernel-devel`, enables
persistence, and versionlocks installed kernel package names. Review its proposed transaction and any prompts.

Before accepting a reboot, collect:

```bash
dkms status
rpm -q "kernel-devel-${TARGET_KERNEL}" "kernel-headers-${TARGET_KERNEL}"
modinfo -k "$TARGET_KERNEL" -F version nvidia
modinfo -k "$TARGET_KERNEL" -F license nvidia
modinfo -k "$TARGET_KERNEL" -F signer nvidia
dnf versionlock list
```

Require a DKMS result for the exact target kernel and driver version. Under
Secure Boot, verify the module signer against the site's approved trust path.
Capture the DNF transaction ID and relevant DKMS build log. Reboot using the
approved operational window after those checks.

## 12. Validate after reboot

Reuse the kernel recorded for this installation and the selected version.
`--kernel` is optional in the client, but an explicit post-reboot assertion
helps detect an unintended boot into a different kernel. Do not replace the
recorded expectation with a fresh `uname -r`:

```bash
sudo ./client-install.sh --validate \
  --kernel "$TARGET_KERNEL" \
  --driver-version 580.196.07 \
  --expected-gpus 6

uname -r
nvidia-smi --query-gpu=index,name,driver_version,pci.bus_id --format=csv
systemctl is-enabled nvidia-persistenced
systemctl is-active nvidia-persistenced
modinfo -F version nvidia
modinfo -F license nvidia
modinfo -F vermagic nvidia
dkms status
dnf versionlock list
journalctl -b -k | grep -Ei 'nvidia|nvrm|xid|lockdown|verification'
```

Acceptance requires the approved kernel, exact selected driver, correct GPU
models and approved count, open module identity, persistence enabled and active,
versionlocks, successful module loading, and no unresolved persistent NVRM/XID
or signature failures. Record fresh evidence after reboot. Package counts or a
metadata-only pass do not establish that result.

Validate the intended application separately against its own RHEL 8.10 support
matrix. The previous deployment's MATLAB version and support assumptions do
not establish this target's application compatibility.

## 13. Patch cycle and rollback

For each future kernel change, approve the new exact target, rebuild and test
the paired repositories with matching development packages, remove the old
kernel versionlocks during the approved transaction, install the kernel and
prerequisites together, verify DKMS, reboot, validate all GPUs, and reapply the
locks. Never let an unattended kernel update outrun its NVIDIA build inputs.

Retain a verified bootable OS rollback kernel and the previous known-good
repository/transaction evidence. A rollback kernel provides GPU service only
if a compatible module was built and signed for that exact kernel. Do not
promise GPU operation from a kernel retained solely for OS recovery. On
failure, preserve DKMS logs, the DNF history, module signer information, and the
kernel journal; execute the site's approved rollback rather than layering a
`.run` driver over the RPM installation.

## Interrupted build recovery

If a build stopped before it wrote `MANIFEST.txt` or `SHA256SUMS`, retain the
downloaded packages and rerun the same broad build with an explicit resume:

```bash
sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels --driver-version 580.196.07 \
  --output "$PWD/dist/rhel8-build" --resume
```

The builder checks all cached RPM identities and signatures again. Completed
bundles cannot be resumed or overlaid; use a new output directory.
