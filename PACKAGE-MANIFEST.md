# Required package manifest

This file defines the RHEL 8.10 build inputs. It is not evidence that a binary
payload has been built or that dependency closure has passed. The target's
exact kernel is unknown, so the broad build includes all available standard
RHEL 8.10 exact kernel development pairs discovered from entitled metadata.

## Target selections

```text
OS and architecture: RHEL 8.10 x86_64
Kernel scope: --all-kernels for available stock EL8.10 pairs, or --target-kernel
Actual included kernels: generated SUPPORTED_KERNELS.txt
Driver branch: R580
Default driver version: 580.196.07
DNF stream: nvidia-driver:580-open
Kernel module: Open-DKMS
NVIDIA package source: https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/
Dependency sources: entitled matching RHEL 8 repositories and EPEL 8
```

For a single-kernel build, populate `TARGET_KERNEL` from the GPU target's
recorded `uname -r`. Broad coverage uses enabled repository metadata. Never
infer the target kernel from the staging host. Never substitute an EL9
RPM, a different distribution's kernel-devel package, or an approximate kernel
version.

## NVIDIA repository content

All driver-versioned packages must resolve to the selected exact version,
default `580.196.07`, from the EL8 repository:

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

These 17 names follow the upstream `580-open/default` profile selected for
this port. The builder also includes `dnf-plugin-nvidia`, whose independent
package version does not equal the GPU driver version. Check the generated
manifest for the selected NEVRAs, architectures, and RPM count for each build.
The full runtime solve can add NVIDIA-signed support packages, including EGL
components, whose independent package versions also need not equal the GPU
driver version. The reviewed independent NVIDIA-source allowlist is
`dnf-plugin-nvidia`, `egl-gbm`, `egl-wayland`, `egl-wayland2`, `egl-x11`, and
`libvdpau`; other driver families, proprietary kmods and toolkit packages remain
ineligible. These support packages remain part of the driver transaction;
they do not authorize a CUDA Toolkit or unrelated application runtime.

The expected Open-DKMS filename for the default version is:

```text
kmod-nvidia-open-dkms-580.196.07-1.el8.noarch.rpm
```

`nvidia-driver-cuda` and `nvidia-driver-cuda-libs` provide driver-side compute
components. Their names do not mean the CUDA Toolkit is being installed.

## RHEL 8 / EPEL 8 prerequisite content

The builder requests the following packages and their resolved dependencies.
In `--all-kernels` mode, the first two specifications apply to every discovered
standard EL8.10 pair; these are alternatives for later client selection, not a
request to install every kernel-headers version simultaneously:

```text
kernel-devel-${TARGET_KERNEL}
kernel-headers-${TARGET_KERNEL}
gcc
gcc-c++
make
python36
/usr/bin/python3.6
dkms
elfutils-libelf-devel
python3-dnf-plugin-versionlock
mokutil
pciutils
```

`${TARGET_KERNEL}` means a listed exact kernel in broad mode or the GPU
target's recorded exact value in single-kernel mode. The builder must locate
and verify both kernel packages and preserve the vendors' original RPM
signatures. `SUPPORTED_KERNELS.txt` is the coverage boundary: availability in
enabled entitled metadata at build time, not every historical/custom/future
kernel. The client requires exact `kernel-devel` for the running kernel. An
installed compatible RHEL `kernel-headers` package is preserved; userspace
headers need not equal `uname -r`. If headers are absent, the carried matching
header package is installed. All discovered exact pairs remain transported for
coverage and reproducibility. Kernel images are not provisioned by this driver
workflow. RHEL 8 dependency sources may require
CodeReady Linux Builder in addition to BaseOS, AppStream, and EPEL 8. Confirm
that the staging host's enabled repositories match the target's RHEL 8.10
content baseline.

The generated `MANIFEST.txt` lists actual RPM filenames. `OS_DEPENDENCIES.tsv`
records selected kernel dependency identities; inspect the manifest for the
entire resolved dependency set. `DKMS_FALLBACK_SETS.tsv` and `DRIVER_SETS.tsv`
record the driver sets the builder actually selected. `COVERAGE.txt` describes
upstream precompiled-open observations and is not target installation evidence.
`RUNTIME_DEPENDENCIES.tsv` maps each freshly resolved runtime RPM filename to
its signed-vendor repository destination. `OFFLINE_INSTALL_PREVIEW.txt` records
the actual final paired-only fresh-installroot transaction preview. The builder
requires a resolved `Transaction Summary` followed by its intentional
`Operation aborted.` refusal before creating the completion manifest/archive.
No RPM is installed by that preview. In broad mode it uses the latest carried
kernel pair, not a DKMS or per-kernel execution proof for every alternative.

## Full runtime closure and required isolated acceptance

The revised builder resolves the exact 17-package driver profile, independently
versioned DNF plugin, and complete toolchain/runtime prerequisites in a fresh
empty installroot. It sets `--releasever=8.10`,
`--setopt=module_platform_id=platform:el8` and an explicit source-repository
allowlist. The official NVIDIA repository is temporary to that command, with
`module_hotfixes=true` scoped to it for exact resolution. Host repository/module
configuration and installed host packages are not used as the dependency baseline
or changed by that solve.

After isolated vendor-key verification, NVIDIA-signed runtime RPMs are included
in `drivers/` and Red Hat/EPEL-signed runtime RPMs in `os-deps/`. Thus OS libraries
required by the full driver are part of the intended output, alongside the
kernel development alternatives and toolchain. The generated manifest is the
actual list; no fixed 18-NVIDIA or total-RPM count is an invariant.

The default source IDs are RHEL 8 BaseOS, AppStream, CodeReady Linux Builder and
EPEL. Repeated `--source-repoid ID` arguments replace that list when approved
content views use different literal IDs. This selects connected build inputs;
it is not permission to depend on an unknown OS repository at the offline site.

A first signed bundle resolved the toolchain but its full driver solve exposed
missing runtime requirements. That result is not full offline acceptance. The
revised design must pass a fresh empty-installroot solve using **only** the
final `drivers/` and `os-deps/` repositories for the full driver, toolchain and
one selected exact kernel. Independent native paired-only proof has passed for the reviewed 23-NVIDIA /
594-OS (617-RPM) union: full pinned driver/toolchain plus kernel
`4.18.0-553.180.1.el8_10.x86_64` resolved 410 packages, approximately 666 MiB,
in an empty installroot; `--assumeno` aborted with zero installed RPMs. Only
the two generated repositories were enabled. Final artifact acceptance still
requires the automated bundle's included successful `OFFLINE_INSTALL_PREVIEW.txt`
and final manifest/hash verification; this intermediate proof is not a final
archive receipt. Keep `module_hotfixes=1` on the verified dependency
repository, which carries AppStream modular RPMs without mirroring all upstream
Red Hat module metadata.

Test kernel alternatives separately; headers versions are not installed
together. Resolve any remaining missing dependencies at connected staging,
rebuild and reverify in a fresh output, and repeat the paired-only acceptance.
Do not rely on preinstalled staging libraries or add an unverified site OS
repository to make the test pass. A successful solver proves package dependency
closure, not package-scriptlet behavior, DKMS compilation, Secure Boot loading
or GPU operation; those require separate disposable/target validation.

Record source IDs, target OS/kernel, selected NEVRAs, exact repository
restrictions, transaction result, signature results, bundle digest and remaining
validation. Do not reuse the old RHEL 9 counts as acceptance criteria.

## Deliberately excluded

```text
CUDA Toolkit, cuDNN, TensorRT, MATLAB, other application runtimes
NVIDIA .run installer
proprietary kmod-nvidia
EL9 RPMs
Red Hat subscription certificates and CDN client keys
repository credentials and license files
private module-signing keys or MOK material
private host evidence
```
