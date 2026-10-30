# Offline assistant context: RHEL 8.10 NVIDIA R580 air-gap workflow

## Task and present state

Help an operator prepare, verify, transfer, import, install, and diagnose an
NVIDIA **driver-only** bundle on RHEL 8.10 x86_64. Read this file together with
`INSTALL.md`, the transported scripts, `MANIFEST.txt`, `SHA256SUMS`, and the
actual generated TSV records. Treat current target evidence as authoritative
when it conflicts with prose. State disagreements and unknowns explicitly.

This repository ports the earlier RHEL 9 tooling. The verified October 30
RHEL 8.10 release carries 104 exact development/header alternatives and 617
signed RPMs. Its complete archive is split into two GitHub Release assets;
follow `GITHUB-DOWNLOAD.md` and verify the pinned reconstructed archive hash.
The target kernel is unknown; discover it at the site and require its exact
carried development package. The actual release passed paired-only dependency
and RPM transaction tests for the latest carried kernel pair. Other kernels'
DKMS builds and real GPU operation remain untested. Prior RHEL 9 counts and
assets are separate evidence. Source predecessor:
`BenjaminSisko/nvidia-r580-rhel9-airgap` at commit `4d492b8`.

## Selected inputs and unresolved facts

```text
Operating system: RHEL 8.10
Architecture: x86_64
Target kernel: UNKNOWN; discover at the first site visit
Build kernel scope: --all-kernels; stock EL8.10 pairs from enabled entitled metadata
Actual covered kernel list: generated SUPPORTED_KERNELS.txt
GPU family: NVIDIA RTX PRO 6000 Blackwell
GPU edition / PCI ID: must be confirmed on target
Expected GPU count: six carried from prior deployment; confirm actual count
Driver branch: R580
Default driver version: 580.196.07
Kernel module: Open
Build mechanism: DKMS
DNF module stream: nvidia-driver:580-open
NVIDIA source: https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/
Driver repository ID: nvidia-r580-rhel8-internal
Dependency repository ID: nvidia-r580-rhel8-os-deps
Example publication URL prefix: /repos/nvidia-r580-rhel8/
```

NVIDIA's R580 release support table explicitly lists RTX PRO 6000 Blackwell
**Server Edition** with RHEL 8.10. Do not generalize that table to an unverified
GPU edition. The EL8 index contains
`kmod-nvidia-open-dkms-580.196.07-1.el8.noarch.rpm`. Upstream support and RPM
presence do not prove compilation, firmware compatibility, Secure Boot loading,
or application compatibility on this specific machine.

Relevant connected source references, retained for future revalidation:

- https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-105-08/index.html
- https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/
- https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/kernel-modules.html
- https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/kernel_open.html
- https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/supportedchips.html

The exact-version module guidance requires open modules for Blackwell and
later. The supported GPU list includes Workstation, Max-Q Workstation, and
Server editions of RTX PRO 6000 Blackwell. Hardware inclusion and the Server
Edition OS table are distinct evidence; confirm the actual installed variant.

The intended application and version are unconfirmed. Do not carry over MATLAB
2026 guarantees from the earlier RHEL 9 deployment. Driver OS support and an
application's OS support are separate checks. Do not install CUDA Toolkit,
cuDNN, TensorRT, MATLAB, or other workloads within this driver-only scope.

## Broad coverage and the exact kernel rule

The operator has not yet seen the target box. Use builder `--all-kernels` to
discover every available standard RHEL 8.10 kernel-devel version exposed by the
enabled entitled metadata and include its exact kernel-headers partner. The
actual list is `SUPPORTED_KERNELS.txt`. This is availability-bounded coverage,
not every kernel ever released, a custom kernel, or future errata. Do not infer
the target from the staging host's kernel.

Alternative kernel development RPMs are transported together for later client
selection. Kernel-headers alternatives are not installed simultaneously, and
the driver workflow does not provision kernel images. Build inclusion alone
does not prove DKMS compilation or GPU operation on each included kernel.

At the site, confirm RHEL 8.10 x86_64 and capture the target's running `uname -r`.
The client selects that value by default. Exact `kernel-devel` matching the
running kernel must be available in the offline dependency repository. The
bundle still carries every discovered matching header alternative:

```text
kernel-devel-${TARGET_KERNEL}
kernel-headers-${TARGET_KERNEL}
```

Do not force installed compatible RHEL `kernel-headers` to equal `uname -r`:
these are userspace headers, not the module build tree. Preserve installed
compatible RHEL headers. Only when headers are absent should the client install
the carried matching header. Exact `kernel-devel` remains mandatory in all
cases. All 104 discovered exact development/header pairs remain transported;
this client rule does not remove coverage packages from the bundle.

Optional client `--kernel` asserts a separately recorded approved value. If
coverage is absent, stop and obtain the exact signed pair in a new connected
build, or perform a separate approved OS change to a covered kernel. Never
approximate a match or substitute another distribution's packages. Capture the
installation kernel and compare it after reboot; do not replace the expectation
with a fresh boot's `uname -r`.

When an exact target becomes known, a smaller build may use
`--target-kernel "$TARGET_KERNEL"` instead of `--all-kernels`, with the variable
populated from the GPU target's recorded output. Never silently infer or shorten
the kernel string. A custom/unsupported kernel requires a separate engineering
and support decision.

## Build modes and their evidence limits

`--metadata-only` reads public NVIDIA metadata and verifies the NVIDIA key
fingerprint. It needs no target kernel, DNF, RPM, or Red Hat entitlement. It
downloads no RPM payload. It establishes no RHEL dependency availability,
complete offline transaction, DKMS build, or GPU operation.

`--dry-run` requires either `--all-kernels` or a known `--target-kernel`, plus a
connected, entitled RHEL 8.10 x86_64 staging host with the relevant RHEL 8/EPEL
8 repositories. It checks selected NVIDIA packages, discovered exact kernel
pairs, and named OS prerequisite availability without RPM payload download.
It does not prove complete transaction closure.

A full build resolves the complete selected driver, toolchain and runtime
closure in a fresh empty RHEL 8.10 installroot. It uses explicit release/platform
settings and only the approved entitled RHEL/EPEL IDs plus a command-temporary
official NVIDIA repository. The NVIDIA source alone receives a scoped
`module_hotfixes=true` during connected resolution; host repository/module state
is unchanged. Extra NVIDIA-signed support RPMs, including independently versioned
EGL components, go to `drivers/`; Red Hat/EPEL-signed dependencies go to
`os-deps/` after isolated vendor-signature verification.

The paired repositories are intended to supply the complete driver/toolchain
transaction without an external or assumed site OS repository. A first signed 505-RPM
bundle passed a 281-package toolchain-only solve but its full driver solve
reported 32 unique missing requirements. The revised runtime-closure build
addresses that gap. Independent native paired-only resolution has now passed
for a reviewed union of 23 NVIDIA and 594 Red Hat/EPEL RPMs (617 total). A fresh
empty installroot with only two generated local repositories resolved the full
pinned driver, toolchain (`gcc`, `gcc-c++`, `python36`, DKMS) and latest carried
`4.18.0-553.180.1.el8_10.x86_64` pair: 410 packages, approximately 666 MiB.
The intentional `--assumeno` abort left zero RPMs installed. The final automated
artifact must still include its own passing `OFFLINE_INSTALL_PREVIEW.txt` and
final manifest/signature/hash checks; no archive completion is asserted here. File counts, valid signatures and a passing seed/toolchain query
are insufficient.

Required acceptance is a fresh empty-installroot solve using only final
`drivers/` and `os-deps/`, all selected driver packages, `gcc`, `gcc-c++`, `make`,
`python36`, `/usr/bin/python3.6`, DKMS and other prerequisites, plus one exact
kernel development/header pair. Empty state prevents preinstalled staging
libraries from concealing omissions. Test kernel alternatives separately. Keep
`module_hotfixes=1` scoped to the verified dependency repository, which carries
AppStream modular RPMs without the complete upstream Red Hat module metadata.
A solver pass does not establish package-scriptlet, DKMS, signing or GPU success.

The builder defaults to standard BaseOS, AppStream, CodeReady Linux Builder and
EPEL source IDs. Repeated `--source-repoid ID` arguments replace them for approved
custom content views. Connected resolution uses `--installroot`,
`--releasever=8.10`, `--setopt=module_platform_id=platform:el8` and
`--setopt=reposdir=/etc/yum.repos.d` with an explicit allowlist. Offline
acceptance must not quietly enable these connected sources or a third site repo.

Inspect final artifact size before selecting media; broad coverage can exceed a
chosen disc capacity. Resolve missing dependencies at connected staging,
rebuild/reverify in a fresh output, and repeat final paired-only acceptance.

The build tooling needs Python 3.9+. Use `PYTHON_BIN` to select an installed
interpreter, for example `/usr/bin/python3.9`. Do not replace RHEL's platform
Python. The bundled `python36`/Python 3.6 components satisfy EL8 package
requirements; they are distinct from the builder's Python 3.9+ interpreter. The shell client/importer include `rhel8-common.sh`; transport that
helper alongside them. Entitled BaseOS, AppStream, and CodeReady Linux Builder
plus EPEL 8 may be needed to resolve the RHEL 8 prerequisite set.

## Package and repository invariants

The generated bundle has:

```text
drivers/       NVIDIA EL8 signed driver/support RPMs plus upstream module metadata
os-deps/       exact kernel development alternatives and full RHEL 8/EPEL 8 runtime/toolchain dependencies
keys/          public Red Hat and EPEL 8 signing keys
NVIDIA-GPG-KEY-D42D0685.pub
MANIFEST.txt, SHA256SUMS, COVERAGE.txt
DRIVER_SETS.tsv, DKMS_FALLBACK_SETS.tsv, OS_DEPENDENCIES.tsv
SUPPORTED_KERNELS.txt, RUNTIME_DEPENDENCIES.tsv, OFFLINE_INSTALL_PREVIEW.txt
client-install.sh, repo-server-import.sh, rhel8-common.sh
docs/INSTALL.md, docs/LLM-CONTEXT.md, PACKAGE-MANIFEST.md
nvidia-r580-internal.repo.example
```

All driver-versioned packages match the selected exact driver version. The
profile names are:

```text
kmod-nvidia-open-dkms
libnvidia-cfg
libnvidia-fbc
libnvidia-gpucomp
libnvidia-ml
nvidia-driver
nvidia-driver-cuda
nvidia-driver-cuda-libs
nvidia-driver-libs
nvidia-kmod-common
nvidia-libXNVCtrl
nvidia-libXNVCtrl-devel
nvidia-modprobe
nvidia-persistenced
nvidia-settings
nvidia-xconfig
xorg-x11-nvidia
```

`dnf-plugin-nvidia` and extra NVIDIA-signed support packages such as EGL
components use independent versions; only the driver-profile package versions
are pinned to the exact selected driver.
`nvidia-driver-cuda` and `nvidia-driver-cuda-libs` are driver compute components,
not the CUDA Toolkit. No arbitrary proprietary `kmod-nvidia` substitution is
allowed. Use the open stream and exact matching userspace.

The dependency seeds include `gcc`, `gcc-c++`, `make`, `python36`,
`/usr/bin/python3.6`, `dkms`, `elfutils-libelf-devel`,
`python3-dnf-plugin-versionlock`, `mokutil`, `pciutils`, and both exact kernel
development packages. The actual manifest and isolated transaction test govern
completeness. The revised build includes runtime closure beyond these seeds;
a seed-list or toolchain-only solve is not complete driver acceptance. Keep
`drivers/repodata/` and its module metadata intact when transferring or mirroring.

## Trust and security boundary

The pinned NVIDIA public-key fingerprint is:

```text
610C7B14E068A878070DA4E99CD0A493D42D0685
```

Expected client public-key paths are:

```text
/etc/pki/rpm-gpg/NVIDIA-GPG-KEY-D42D0685.pub
/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
```

Public keys are distinct from entitlement/client credentials. Confirm public
key provenance through an approved source. Never upload or transport Red Hat
subscription certificates, CDN private keys, passwords, private signing keys,
license files, or private target evidence. Keep vendor RPMs out of Git and
respect their original license/redistribution terms.

Keep RPM `gpgcheck=1`, HTTPS `sslverify=1`, and vendor signatures. The example
uses `repo_gpgcheck=0` because generated metadata is unsigned. Use authenticated
approved transport or the required site metadata-signing process. Never bypass
verification to cure a missing key. Keep the approved transport checksum in an
authenticated record outside the bundle; checksum files replaced with the
payload do not authenticate it by themselves.

Secure Boot requires the site's approved DKMS signing and host-trust process.
These tools do not generate keys, enroll MOKs, or change Secure Boot. A package
transaction and DKMS compilation do not prove a module can load under Secure
Boot. Never disable Secure Boot or invent a new key-enrollment workflow as a
shortcut.

## Evidence hierarchy

1. Fresh target output: OS/release, exact kernel, PCI IDs, RPM database, Secure
   Boot state, DKMS logs, module identity, journal, services, and `nvidia-smi`.
2. Actual bundle manifest, hashes, signatures, generated TSVs, and DNF metadata.
3. Current transported scripts and their help output.
4. This document and `INSTALL.md`.
5. Prior deployment records and recollections.

When evidence conflicts, explain it and gather the missing source. Do not
report success from package installation, a green metadata check, or GPU count
alone. Full acceptance needs the correct driver and kernel, all approved GPUs,
loaded open modules, service health, signing compliance, and clean diagnostics.

## Operator workflow

First collect on target:

```bash
cat /etc/redhat-release
uname -m
uname -r
rpm -q kernel-core
lspci -nn -d 10de:
mokutil --sb-state
rpm -qa | grep -E '^(nvidia|libnvidia|kmod-nvidia|cuda)' | sort
```

Before the site visit, stage broad coverage on the entitled build host:

```bash
PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh --metadata-only

sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels --driver-version 580.196.07 --dry-run

sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels --driver-version 580.196.07 \
  --output "$PWD/dist/rhel8-build"

cat dist/rhel8-build/repo-bundle/SUPPORTED_KERNELS.txt
```

For a known single target, replace `--all-kernels` with `--target-kernel` and
its separately recorded exact target value. Metadata-only needs neither mode.

Review signatures, exact packages, hashes, and pair-only transaction closure,
then transfer through approved media. On the offline repository server:

```bash
sudo ./repo-server-import.sh --source /mnt/nvidia-media   --destination /srv/repos/nvidia-r580-rhel8
```

For tar extraction, point source to `repo-bundle/`. Configure both internal
client repos using the approved URLs/keys. Confirm the running kernel is
covered. Retain `rhel8-common.sh` beside the client script. On target, capture
and record the selected kernel for an optional explicit assertion:

```bash
TARGET_KERNEL="$(uname -r)"

sudo ./client-install.sh --kernel "$TARGET_KERNEL" \
  --driver-version 580.196.07 --expected-gpus 6 --dkms-fallback
```

Six is still an assumption pending target evidence. `--dkms-fallback` is
explicit because compiler and DKMS installation change the package baseline.
The client otherwise defaults to running `uname -r`; when `--kernel` is
supplied, it must equal that assertion. Exact `kernel-devel` must be available
in the offline dependency repository before installation. Preserve compatible
installed RHEL `kernel-headers`; install the carried matching header only when
headers are absent. Before reboot, verify DKMS and
the approved signing path. After reboot:

```bash
sudo ./client-install.sh --validate --kernel "$TARGET_KERNEL" \
  --driver-version 580.196.07 --expected-gpus 6

uname -r
nvidia-smi --query-gpu=index,name,driver_version,pci.bus_id --format=csv
dkms status
modinfo -F version nvidia
modinfo -F license nvidia
modinfo -F vermagic nvidia
modinfo -F signer nvidia
systemctl is-enabled nvidia-persistenced
systemctl is-active nvidia-persistenced
dnf versionlock list
journalctl -b -k | grep -Ei 'nvidia|nvrm|xid|lockdown|verification'
```

Record the actual results. A non-hardware disposable VM can test transaction
closure, but cannot establish final GPU acceptance and may not pass the client
hardware guard. Do not bypass production guards to force a test result.

## Troubleshooting map

| Symptom | Required evidence and action |
|---|---|
| Kernel rejected or not covered | Compare `uname -r`, `SUPPORTED_KERNELS.txt`, exact kernel-devel, the installed-or-carried RHEL userspace headers, optional `--kernel` assertion, and `grubby --default-kernel`. Obtain an exact signed pair or use an approved OS change to a covered kernel. |
| Exact development RPM unavailable | Check entitled matching RHEL 8 sources and content baseline. Obtain exact Red Hat packages; never substitute another kernel or distribution. |
| Missing offline dependency | Capture pair-only DNF resolver output on a clean matching baseline. Add the correct signed RHEL 8/EPEL 8 dependency through the connected build and regenerate metadata/hashes. |
| Python syntax/version failure | Select installed Python 3.9+ with `PYTHON_BIN` on the build host; preserve system platform Python. |
| DKMS failure | Capture `dkms status`, exact kernel-devel identity, `/var/lib/dkms/nvidia/.../make.log`, compiler errors, and kernel logs. Fix the actual build/signing cause before retrying. |
| Module rejected under Secure Boot | Capture `mokutil --sb-state`, `modinfo -F signer nvidia`, and lockdown/signature journal messages; use the approved signing/trust procedure. |
| Driver/library mismatch | Compare loaded `/proc/driver/nvidia/version`, module version, installed NVIDIA RPM versions, and the selected bundle. Reboot only after a coherent transaction and signed target module are verified. |
| GPU count differs | Compare `lspci -nn -d 10de:`, `nvidia-smi -L`, topology, and PCIe/AER/NVRM logs. Investigate enumeration, power, firmware, risers, and hardware when PCI evidence is incomplete. |
| Module stream unavailable | Inspect both repo IDs and `drivers/repodata/repomd.xml`; confirm upstream module metadata survived transport. Do not solve by mixing unrelated streams. |

For a DKMS build failure, example read-only collection:

```bash
dkms status
rpm -q "kernel-devel-${TARGET_KERNEL}" kernel-headers
find /var/lib/dkms/nvidia -name make.log -type f -print
journalctl -b -k | grep -Ei 'nvidia|lockdown|verification|secure'
```

Never layer a `.run` installer over RPMs, mix driver versions, install the CUDA
Toolkit as a driver repair, disable signature checks, or remove kernel guards.

## Change record and maintenance

Record tooling revision; target OS/kernel, GPU IDs/edition/count; driver
version; actual RPM NEVRAs; clean-baseline closure test; signature/key results;
bundle digest and `SUPPORTED_KERNELS.txt`; transfer/import result; approved Secure Boot/signing path; DNF
transaction; DKMS logs/status; post-reboot GPU evidence; persistence health;
versionlocks; and verified rollback plan. Mark pending items explicitly.

For a kernel patch, approve the exact new target, rebuild/test the paired
repos, unlock during the approved transaction, install new kernel and matching
prerequisites together, verify DKMS and signing, reboot, validate all GPUs,
and relock. A retained old kernel is only an OS rollback unless its compatible
NVIDIA module and signing were separately verified. Preserve logs and use the
approved rollback procedure on failure.

## EL8 RPM header licensing and interrupted builds

The official signed `kmod-nvidia-open-dkms-580.196.07-1.el8.noarch.rpm`
reports `NVIDIA License` in its RPM header. That field describes the package
and must not be used as the kernel-module flavor test. Its signed description
identifies open-source modules, and the transported source file
`/usr/src/nvidia-580.196.07/kernel-open/nvidia/nv.c` carries an MIT SPDX tag.
Use the exact open package name/version/release, pinned vendor trust, upstream
module membership, and the loaded Open Kernel Module validation together.
The proprietary `kmod-nvidia` and `kmod-nvidia-latest-dkms` packages remain
ineligible for Blackwell.

An interrupted payload build may be retried with `--resume` and the same
`--output` only while the output is incomplete. The option retains downloaded
RPMs but reruns identity and signature verification. A completed bundle with
`MANIFEST.txt` or `SHA256SUMS` is immutable to this option; select a fresh output
for another completed build. Never delete completion markers to force a retry.


For a fresh rebuild that reuses prior payload, `--rpm-cache DIR` accepts the
previous `repo-bundle/` and imports **only RPMs** into a new `--output`.
Identity/signature verification and full runtime resolution run again; all
metadata, manifests and checksums are newly generated. It must not copy old
completion claims, and it cannot be combined with `--resume`. Keep the earlier
incomplete-only resume rule above; never remove completed-bundle markers.


The runtime support allowlist is the independently versioned DNF plugin plus
`egl-gbm`, `egl-wayland`, `egl-wayland2`, `egl-x11` and `libvdpau` from the
reviewed NVIDIA source. Other driver families, proprietary kmods and toolkits
remain rejected. `RUNTIME_DEPENDENCIES.tsv` maps every fresh runtime RPM to its
signed-vendor repository destination. `OFFLINE_INSTALL_PREVIEW.txt` is the
actual paired-only fresh-installroot DNF preview for the latest carried kernel
pair. Completion requires a resolved `Transaction Summary` and the intentional
`Operation aborted.` refusal, with no RPM installed. Inspect that file rather
than inferring success from a manifest or a seed query. Its single selected
kernel does not establish all-kernel DKMS/GPU execution or real target acceptance.
