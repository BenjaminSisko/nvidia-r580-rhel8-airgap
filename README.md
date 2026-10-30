# NVIDIA R580 Open-DKMS air-gap repository for RHEL 8.10

This project prepares a driver-only offline DNF bundle for RHEL 8.10 x86_64
and NVIDIA RTX PRO 6000 Blackwell GPUs. It ports the earlier RHEL 9 workflow
using NVIDIA's **EL8** RPMs, RHEL 8 dependencies, and EPEL 8. The original
`BenjaminSisko/nvidia-r580-rhel9-airgap` repository at commit `4d492b8` remains
unchanged; this repository contains the separate RHEL 8 adaptation.

| Item | Selection or evidence needed |
|---|---|
| Target OS | RHEL 8.10 x86_64 |
| Kernel coverage | `--all-kernels` includes available stock RHEL 8.10 kernel development pairs; target kernel is unknown |
| GPU variant | RTX PRO 6000 Blackwell; confirm exact edition and PCI ID on target |
| Expected GPU count | Six, carried from the prior deployment; confirm on target |
| Driver branch / default version | R580 / `580.196.07` |
| Kernel module / build | Open / DKMS |
| DNF module stream | `nvidia-driver:580-open` |
| Driver repository ID | `nvidia-r580-rhel8-internal` |
| Dependency repository ID | `nvidia-r580-rhel8-os-deps` |

NVIDIA's R580 release support matrix explicitly lists RTX PRO 6000 Blackwell
**Server Edition** with RHEL 8.10. Confirm the hardware variant before applying
that support statement to this machine. The EL8 repository currently contains
`kmod-nvidia-open-dkms-580.196.07-1.el8.noarch.rpm`. These are upstream support
and package-availability facts; successful DKMS compilation and GPU operation
on the target still need validation. See the [NVIDIA R580 release notes](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-105-08/index.html)
and [NVIDIA RHEL 8 package index](https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/).
NVIDIA's [580.196.07 kernel-module guidance](https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/kernel_open.html)
requires the open modules for Blackwell and later. Its [supported GPU list](https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/supportedchips.html)
includes the Workstation, Max-Q Workstation, and Server editions of RTX PRO 6000
Blackwell; confirm the installed variant separately from the Server Edition OS
support matrix.

## Current delivery status

A completed local bundle was built and independently checked on October 30,
2026. It contains **104 exact stock RHEL 8.10 kernel development/header pairs**,
NVIDIA **580.196.07**, and the complete tested driver/build/runtime dependency
set. The 2.63 GB archive and its SHA-256 are recorded in the
[verified build receipt](docs/BUILD-RECORD-20261030.md). Download the complete
kit from the [GitHub release](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/tag/v2026.10.30-r580.196.07)
and follow [the download/reassembly guide](docs/GITHUB-DOWNLOAD.md). The archive
is split into two release assets to fit GitHub's per-file limit. No production
repository service or GPU target was changed by publication.

The target kernel remains unknown. Coverage is bounded by the exact signed
pairs available in the entitled repositories at build time; it does not cover
every historical, custom or future kernel. Review `SUPPORTED_KERNELS.txt`.
Target installation, DKMS compilation, Secure Boot handling and post-reboot GPU
validation remain site-visit work.

The generated transport bundle has two repositories:

- `drivers/`: signed EL8 NVIDIA R580 Open-DKMS, matching versioned userspace,
  and NVIDIA-signed support dependencies such as independently versioned EGL
  components.
- `os-deps/`: exact Red Hat kernel development package alternatives, the DKMS
  toolchain, and the resolved RHEL 8/EPEL 8 runtime dependencies needed by the
  full driver transaction.

The revised build resolves the full selected driver and toolchain from a fresh
empty RHEL 8.10 installroot, using only approved entitled RHEL/EPEL sources and
a temporary official NVIDIA source. It classifies downloaded RPMs by isolated
vendor signature verification and includes them in the repository pair. This
addresses a real first-build finding: valid signatures and a passing toolchain
solve did not prove the driver runtime dependencies were complete. Independent native paired-only proof has passed: 23 reviewed NVIDIA RPMs plus
594 Red Hat/EPEL RPMs resolved the full driver/toolchain and latest carried
kernel pair as a 410-package, approximately 666 MiB transaction in an empty
installroot. The preview aborted with zero RPMs installed and no third
repository. The completed artifact also passed its own automated
`OFFLINE_INSTALL_PREVIEW.txt` gate and a separate RPM transaction test with
signatures and file-conflict checks enabled; zero application RPMs were
installed. The archive and all 654 per-file checksums passed after transfer.
The builder withholds its completion manifest/archive until the paired-only
preview passes; inspect that receipt and `RUNTIME_DEPENDENCIES.tsv`.
The automatic preview uses the latest carried kernel pair; it does not prove
DKMS or solver execution for all 104 alternatives.

The CUDA Toolkit, cuDNN, TensorRT, MATLAB, entitlement material, credentials,
private signing keys, and private host evidence are outside the payload.
Driver support does not establish support for a particular MATLAB release or
other application on RHEL 8.10; the workload and application version remain
unconfirmed.

## Download the prepared kit

The release contains the complete 617-RPM kit and all 104 exact kernel
development/header pairs. Download all release assets, then run the supplied
helper on Linux or macOS:

```bash
gh release download v2026.10.30-r580.196.07 \
  --repo BenjaminSisko/nvidia-r580-rhel8-airgap \
  --dir nvidia-rhel8-download
cd nvidia-rhel8-download
bash reassemble-release.sh
```

See [the full download guide](docs/GITHUB-DOWNLOAD.md) for manual reassembly
and inner checksums. The automatically generated GitHub source ZIP/TAR
contains tooling; the release assets contain the binary offline kit.

## Check upstream metadata

The metadata-only mode checks public NVIDIA sources without a target kernel,
DNF, RPM, or Red Hat entitlement. It downloads no RPM payload and proves no
RHEL dependency closure:

```bash
./scripts/build-driver-repo.sh --metadata-only
```

The scripts require Python 3.9 or newer. On RHEL 8, do not replace the operating
system's platform Python. Select an installed interpreter explicitly if needed:

```bash
PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh --metadata-only
```

## Build broad kernel coverage before the site visit

Use a connected, entitled **RHEL 8.10 x86_64 staging host** with matching
BaseOS, AppStream, CodeReady Linux Builder, and EPEL 8 sources. Install build
tooling and follow [the full procedure](docs/INSTALL.md):

```bash
sudo dnf install -y \
  curl createrepo_c dnf-plugins-core gnupg2 xorriso rpm-build python39

sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels --driver-version 580.196.07 --dry-run

sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels --driver-version 580.196.07 \
  --output "$PWD/dist/rhel8-build"

cat dist/rhel8-build/repo-bundle/SUPPORTED_KERNELS.txt
```

The broad mode discovers available standard EL8.10 kernel-devel versions and
requires the corresponding kernel-headers package for each included kernel.
The generated list is the actual scope. It carries development packages for
alternative kernels, without installing kernel images on the target. At the
site, the client requires exact matching `kernel-devel`. It preserves an
installed compatible RHEL `kernel-headers` package, whose version need not equal
the running kernel; if headers are absent, it installs the carried matching
header package. A kernel missing
from the bundle must be handled by obtaining an exact signed pair or making a
separate approved OS change; an approximate match is unsafe.

For a smaller bundle after the GPU target is known, pass
`--target-kernel "$TARGET_KERNEL"` instead of `--all-kernels`, setting the
variable from the **GPU target's** recorded `uname -r`. Never use the staging
host's kernel as a guess.

The dry-run checks availability without downloading RPMs. The full build
verifies vendor signatures and creates repositories, hashes, a tarball, and an
ISO unless `--no-iso` is supplied. Validate the full selected transaction using
only the paired repositories before accepting the bundle. Broad coverage can
increase media size substantially; inspect the finished artifact size before
choosing optical media. Build/transfer success does not prove DKMS or GPU
operation on every listed kernel.

For a fresh revision that reuses previously downloaded RPMs, supply the old
`repo-bundle/` directory as a cache while selecting a **new** output directory:

```bash
sudo env PYTHON_BIN=/usr/bin/python3.9 ./scripts/build-driver-repo.sh \
  --all-kernels --driver-version 580.196.07 --no-iso \
  --rpm-cache /path/to/old/repo-bundle \
  --output "$PWD/dist/rhel8-build-r2"
```

`--rpm-cache` imports only RPMs, never old repository metadata, manifests or
completion claims, and reruns identity/signature verification. `--resume` is
for an incomplete output only; a completed bundle cannot be overlaid or resumed.
Do not combine the two options. See [the recovery procedure](docs/INSTALL.md#interrupted-build-recovery).

## Transfer, import, and install

After verifying and transferring approved media, run the bundled importer on
the offline repository server. The source below is the mounted ISO root; for
an extracted tarball, use its `repo-bundle/` directory:

```bash
sudo ./repo-server-import.sh \
  --source /mnt/nvidia-media \
  --destination /srv/repos/nvidia-r580-rhel8
```

Publish `drivers/` and `os-deps/` using the existing repository service and adapt
[the example repository file](config/nvidia-r580-internal.repo.example). Its
example URLs use `/repos/nvidia-r580-rhel8/`. Verify the approved public keys
before installing them on clients.

On the GPU target, first capture its facts:

```bash
cat /etc/redhat-release
uname -r
lspci -nn -d 10de:
mokutil --sb-state
```

The client detects `uname -r` by default and refuses installation when its exact
`kernel-devel` is absent from the dependency repository. It retains compatible
installed RHEL userspace headers; when none are installed, the carried matching
`kernel-headers` package is used. For an
additional assertion, pass `--kernel` with a separately recorded approved value.
Install using the explicit Open-DKMS path:

```bash
sudo ./client-install.sh --driver-version 580.196.07 --dkms-fallback
```

The explicit flag permits installation of `gcc`, `gcc-c++`, `make`, the exact
kernel development package, Python 3.6 components needed by EL8 driver packages,
and DKMS on the target. If Secure Boot is enabled, complete the site's
approved module-signing process before rebooting. The scripts do not create
keys, enroll a MOK, or change Secure Boot. Preserve the selected kernel from the
installation record and use it as the post-reboot assertion:

```bash
TARGET_KERNEL='PASTE_THE_RECORDED_INSTALLATION_KERNEL'
sudo ./client-install.sh --validate --kernel "$TARGET_KERNEL" \
  --driver-version 580.196.07 --expected-gpus 6
```

Use the actual approved GPU count if target evidence differs from six. Full
acceptance also requires service, module, journal, and versionlock checks in
[INSTALL.md](docs/INSTALL.md).

## Documentation

- [Download and reassemble the complete GitHub release](docs/GITHUB-DOWNLOAD.md)
- [Verified October 30 build and SHA-256](docs/BUILD-RECORD-20261030.md)
- [USB/local-repository quickstart](docs/ON-SITE-QUICKSTART.md)
- [Installation, transfer, validation, and rollback](docs/INSTALL.md)
- [Self-contained context for an offline assistant](docs/LLM-CONTEXT.md)
- [Required package manifest and closure boundary](PACKAGE-MANIFEST.md)
- [Security policy and trust model](SECURITY.md)
- [NVIDIA open kernel module installation guidance](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/kernel-modules.html)

## License

The tooling and documentation use the MIT License. Vendor RPMs retain their
own licenses and redistribution terms. Keep generated payloads out of Git and
use the organization's approved artifact-transfer and entitlement procedures.
