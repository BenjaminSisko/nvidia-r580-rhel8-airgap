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
make
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
kernel. The client selects only the running kernel's exact pair and refuses
missing coverage. Kernel images are not provisioned by this driver workflow. RHEL 8 dependency sources may require
CodeReady Linux Builder in addition to BaseOS, AppStream, and EPEL 8. Confirm
that the staging host's enabled repositories match the target's RHEL 8.10
content baseline.

The generated `MANIFEST.txt` lists actual RPM filenames. `OS_DEPENDENCIES.tsv`
records selected kernel dependency identities; inspect the manifest for the
entire resolved dependency set. `DKMS_FALLBACK_SETS.tsv` and `DRIVER_SETS.tsv`
record the driver sets the builder actually selected. `COVERAGE.txt` describes
upstream precompiled-open observations and is not target installation evidence.

## Closure validation requirement

Availability of the named prerequisites, successful RPM download, and valid
signatures are separate from proving a complete offline transaction. This
port has not yet passed that final test for the intended baseline and included kernels. NVIDIA userspace
can require additional OS libraries beyond the DKMS prerequisite seeds.

Before accepting a bundle, test resolution using **only** its `drivers/` and
`os-deps/` repositories against a clean RHEL 8.10 baseline matching the GPU
server. Test an exact pair at a time; alternative kernel-headers versions are
not installed together. Resolve missing dependencies from entitled RHEL 8/EPEL 8 sources,
rebuild and reverify the bundle, and repeat. Do not rely on packages already
installed on the staging host to hide omissions. A disposable matching VM is
the preferred installation test; actual hardware is required for final GPU
acceptance.

Record target OS/kernel, baseline packages, repository IDs, selected NEVRAs,
transaction result, signature results, bundle digest, and remaining validation
in the build record. Do not reuse the old RHEL 9 package counts as acceptance
criteria.

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
