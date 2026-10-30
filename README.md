# NVIDIA R580 Open-DKMS air-gap repository for RHEL 8.10

This project prepares a driver-only offline DNF bundle for RHEL 8.10 x86_64
and NVIDIA RTX PRO 6000 Blackwell GPUs. It ports the earlier RHEL 9 workflow
using NVIDIA's **EL8** RPMs, RHEL 8 dependencies, and EPEL 8. The original
`BenjaminSisko/nvidia-r580-rhel9-airgap` repository at commit `4d492b8` remains
unchanged; this is a separate local sibling containing the source adaptation.

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

This is a local source port. A new GitHub repository, release, and ready-built
RHEL 8 payload have **not** been published. Prepare a broad kernel bundle before
the first site visit with `--all-kernels`; it is bounded by the exact development
package pairs available in the enabled entitled RHEL 8 repositories at build
time. It cannot guarantee coverage of every historical, custom, or future
kernel. Review `SUPPORTED_KERNELS.txt` before transfer. Full build/transaction
evidence belongs to each generated bundle; target installation and post-reboot
GPU validation remain pending. The prior RHEL 9 package counts are not RHEL 8
evidence.

The generated transport bundle has two repositories:

- `drivers/`: signed EL8 NVIDIA R580 Open-DKMS and matching userspace RPMs.
- `os-deps/`: exact target Red Hat kernel development packages and resolved
  RHEL 8/EPEL 8 prerequisites.

The CUDA Toolkit, cuDNN, TensorRT, MATLAB, entitlement material, credentials,
private signing keys, and private host evidence are outside the payload.
Driver support does not establish support for a particular MATLAB release or
other application on RHEL 8.10; the workload and application version remain
unconfirmed.

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
site, the client selects the pair matching its running kernel. A kernel missing
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
development package pair is absent from the dependency repository. For an
additional assertion, pass `--kernel` with a separately recorded approved value.
Install using the explicit Open-DKMS path:

```bash
sudo ./client-install.sh --driver-version 580.196.07 --dkms-fallback
```

The explicit flag permits installation of the compiler, exact kernel development
packages, and DKMS on the target. If Secure Boot is enabled, complete the site's
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

- [Installation, transfer, validation, and rollback](docs/INSTALL.md)
- [Self-contained context for an offline assistant](docs/LLM-CONTEXT.md)
- [Required package manifest and closure boundary](PACKAGE-MANIFEST.md)
- [Security policy and trust model](SECURITY.md)
- [NVIDIA open kernel module installation guidance](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/kernel-modules.html)

## License

The tooling and documentation use the MIT License. Vendor RPMs retain their
own licenses and redistribution terms. Keep generated payloads out of Git and
use the organization's approved artifact-transfer and entitlement procedures.
