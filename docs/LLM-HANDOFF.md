# LLM handoff: RHEL 8.10 Blackwell driver kit and MATLAB preparation

Updated November 2, 2026. Read this before acting on the target. It describes
what exists, what was verified and what remains unknown. Continue the user's
authorized work using the evidence below; ask only for information that cannot
be obtained from the supplied artifacts or target discovery. Do not turn a
successful download or package test into an application acceptance claim.

## Goal and target facts

Prepare an offline RHEL 8.10 x86_64 system with NVIDIA RTX PRO 6000 Blackwell
GPUs for MATLAB, primarily **R2026a**, with possible **R2024a/R2024b** workloads.
The user asked to prepare for all toolboxes. Treat that as broad preparation for
licensed, Linux-supported workflows, not certification of every product.

| Target fact | Current evidence / required discovery |
|---|---|
| OS / architecture | Intended RHEL 8.10 x86_64; confirm on the actual system. |
| GPU model family | RTX PRO 6000 Blackwell; exact Server/Workstation/Max-Q edition and PCI identity unknown. |
| GPU count | Unknown; **six is an earlier configurable default**, not a fresh observation. |
| Running kernel | Unknown; discover on the GPU target, never infer from a staging host. |
| Secure Boot / signing | Unknown; discover and use the site's existing approved signing/trust path. |
| Installed driver / loaded module | Unknown on target; prepared driver is **580.196.07 Open-DKMS**. |
| MATLAB releases / updates / products | R2026a primary, 2024 possibly needed; actual installations, updates and licenses unknown. |
| Workloads / data / multi-GPU strategy | Unknown; establish representative workflows and numerical criteria. |

NVIDIA's [R580 release matrix](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-105-08/index.html)
explicitly covers the Server Edition on RHEL 8.10. The
[580.196.07 product list](https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/supportedchips.html)
also lists the other editions; identify the installed hardware before extending
an OS support statement. Blackwell requires the
[open kernel modules](https://download.nvidia.com/XFree86/Linux-x86_64/580.196.07/README/kernel_open.html).

## Delivery A: published driver repository kit

Repository: [BenjaminSisko/nvidia-r580-rhel8-airgap](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap).
Driver release/tag:
[`v2026.10.30-r580.196.07`](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/tag/v2026.10.30-r580.196.07).
This accepted release remains unchanged by the MATLAB add-on work.

| Property | Accepted value |
|---|---|
| Reconstructed archive | `nvidia-r580-rhel8-driver-repo-20261030.tar.gz` |
| Archive size | **2,632,185,106 bytes** |
| Driver / module stream | **580.196.07**, Open-DKMS, `nvidia-driver:580-open` |
| RPMs | **23 NVIDIA + 594 Red Hat/EPEL = 617** |
| Kernel coverage | **104 exact stock RHEL 8.10 development/header pairs** |
| First / last alternative | `4.18.0-553.el8_10.x86_64` / `4.18.0-553.180.1.el8_10.x86_64` |
| Transport checks | Archive hash and **654 inner file checksums** passed. |
| Offline transaction proof | **410 packages**, latest carried kernel pair, only the two delivered repositories. |
| Strong RPM test | Key/signature/file-conflict checks passed; zero application RPMs installed in the disposable test root. |

Archive SHA-256:

```text
7c55e4f252661830ca917949bfda142ddbf7d4f5ade79235b4a09c3e1c1dc8e7
```

The original gzip remains two ordered byte parts. The preferred newer
transport is one `nvidia-r580-rhel8-driver-repo-20261030.tar.xz` file (**2,024,025,344 bytes**), SHA-256
`f6b127cbd58f0265f6f91978aa61096844007c8b1a7e4eb94c8801fa01503db5`. Both decode to the exact same tar: **4,628,807,680 bytes**, SHA-256
`b3214b0109f825276f7cd9b6f90c0df390d7f6aebdbaf6f0ef0603c2ed104bac`. No payload files or kernel alternatives were changed.
Read [SINGLE-FILE-DOWNLOAD.md](SINGLE-FILE-DOWNLOAD.md) for quick extraction and
[GITHUB-DOWNLOAD.md](GITHUB-DOWNLOAD.md) for the retained original-gzip fallback.
The XZ file/sidecar/record/guide are four added assets; all original ten remain
unchanged. GitHub's automatic source ZIP/TAR contains source tooling rather than
the binary kit. The extracted `repo-bundle/` contains:

- `drivers/`: signed EL8 NVIDIA driver/support RPMs and NVIDIA module metadata.
- `os-deps/`: signed OS/EPEL driver runtime/build dependencies and kernel alternatives.
- Public keys, `SUPPORTED_KERNELS.txt`, `RUNTIME_DEPENDENCIES.tsv`,
  `OFFLINE_INSTALL_PREVIEW.txt`, manifests, checksums and client/import helpers.
- Human/offline-assistant documentation and an optional local `file://` procedure.

See [BUILD-RECORD-20261030.md](BUILD-RECORD-20261030.md). The test did **not** run
on a GPU, compile DKMS on the target, validate Secure Boot, execute MATLAB, or
test all 104 alternatives individually. Coverage is bounded by the entitled
stock snapshot, not every historical/custom/future kernel. No kernel image is
provisioned. Exact running-kernel `kernel-devel` is mandatory; compatible
installed RHEL `kernel-headers` need not match the running kernel and are retained.

## Delivery B: locally verified NVIDIA development-artifact cache

This is a **separate local folder**, not an asset of the October 30 GitHub
release and not a DNF repository. Do not assume a source clone downloads it.
Default relative output: `dist/matlab-nvidia-addons-20261102/`.

| Profile | Files | Pinned download bytes |
|---|---:|---:|
| `cuda-12.8.2` | 33 NVIDIA `linux-x86_64` component `.tar.xz` archives | 4,253,511,164 |
| `tensorrt-10.9.0.34-cuda12.8` | 23 NVIDIA RHEL8 RPMs, full selected SDK set | 5,063,946,188 |
| Total | **56** | **9,317,457,352** |

All 56 downloaded files passed pinned NVIDIA size/SHA-256 checks at
**2026-11-02 14:18:22 UTC**; local delivery was recorded at **14:20:07 UTC**.
The [sanitized preparation receipt](MATLAB-PREPARATION-RECORD-20261102.json)
records the result and explicit false signature/OS-closure/MATLAB-test flags.
Preparation passed **44 tests at `4b36e03`** and
[CI run 41460883789](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/actions/runs/41460883789). That is a
historical verified source checkpoint; later documentation commits may follow.
These facts do **not** establish add-on RPM-signature verification, RHEL OS
runtime closure, SDK assembly/relocation, MATLAB/Octave execution or target tests.
None of those was performed for this add-on preparation.

The CUDA selection excludes driver, Fabric Manager, IMEX, `nvidia_fs` and
NVSwitch library components. TensorRT includes selected runtime/development/
static libraries, headers, plugins/parsers, samples and bindings. Carrying
Python bindings does not install or select a Python environment.

Read [MATLAB-NVIDIA-ASSETS.json](MATLAB-NVIDIA-ASSETS.json) for exact filenames,
versions, sizes, hashes and upstream URLs. The cache has `payload/`,
`ASSET-MANIFEST.json`, `SHA256SUMS` and `FETCH-RECEIPT.json`; inspect their actual
scope/status. The [public payload checksum list](MATLAB-PAYLOAD-SHA256SUMS) has the exact
56 lines from the verified cache, SHA-256
`7eb9cab01eba7935705bbb1c8db3aa19f525d5df4122ce60f490cb0b84d1d90e`.
The fetcher neither extracts nor installs artifacts. CUDA archives
retain component licenses; TensorRT RPMs require separate signature and target
dependency checks before use. Extracted SDKs need additional disk space.

## MATLAB compatibility decisions

| Workflow | Required approach |
|---|---|
| Ordinary `gpuArray` / GPU-enabled toolbox calls | MATLAB + Parallel Computing Toolbox (PCT), function-specific GPU support, supplied libraries and a working driver. External CUDA is not a blanket requirement. |
| Deep learning inside MATLAB | Deep Learning Toolbox + PCT for GPU execution, supplied release libraries and required models/importer packages. |
| Custom `mexcuda` | MATLAB-supplied `nvcc`/CUDA libraries plus a supported host C++ compiler; add custom external dependencies only if the code needs them. |
| GPU Coder MEX / supported Simulink GPU simulation | Required Coder/PCT/Simulink products; supplied MATLAB tools/libraries; TensorRT integration has its own MathWorks installation step. |
| Standalone GPU Coder executable/library/source | R2026a CUDA 12.8 latest update, selected **12.8.2**; TensorRT **10.9** for that target library; external cuDNN target remains blocked as below. |
| Multi-GPU / remote workers | Explicit workload distribution and licensing/configuration; seeing six GPUs does not distribute one operation automatically. |

**R2026a is the native Blackwell path.** R2024a/b support GPU compute capability
5.0–9.x and use a legacy CUDA 12.2-era stack; their documented external options
include TensorRT 8.6.1 and cuDNN 8.9. That legacy stack is **not staged here** and
does not provide native Blackwell support. Installing external CUDA 12.8 does
not replace R2024's supplied CUDA libraries. Forward compatibility can give
wrong answers/unexpected behavior; it needs a separate, bounded numerical test
case. Do not enable it automatically or set `MW_NVCC_PATH` as an upgrade trick.

**External cuDNN is unresolved:** R2026a GPU Coder lists cuDNN 8.9, while NVIDIA
introduced native Blackwell compute capability 10.0/12.0 support in cuDNN 9.7.
Do not silently substitute cuDNN 9.7+ or claim cuDNN 8.9 is a native solution.
Obtain a supported resolution for a required `cudnn` target. For supported
networks, documented `TargetLibrary='none'` generates plain CUDA without external
deep-learning libraries; it still needs standalone CUDA tooling and application
validation. This gap concerns external code generation, not a rejection of
R2026a's supplied-library GPU support.

RHEL 8.10 GCC/G++ **8.5** fits the relevant MathWorks compiler ranges and CUDA
12.8.2's qualified RHEL baseline; the original driver kit carries GCC/G++
dependencies. Do not assume a GCC Toolset upgrade is needed. Static linkage,
other languages and third-party products can add requirements.

[MATLAB-OFFLINE.md](MATLAB-OFFLINE.md) supplies version-specific primary-source
links, compiler tables, supported workflow distinctions and detailed procedures.
MathWorks licensed installers, updates, toolboxes, support packages, models,
datasets and license/activation material are **separate and unavailable in these
NVIDIA kits**. “All toolboxes” is an assumption for gathering requirements, not
an installation/license/function certificate. Some products are unavailable on
Linux. Jetson/DRIVE/embedded support is needed only for actual embedded targets.

## Read evidence in this order

1. Root `AGENTS.md` and current `README.md`: repository-specific instructions and
   links. This handoff is the cross-artifact summary, not an override of the user.
2. [BUILD-RECORD-20261030.md](BUILD-RECORD-20261030.md), the driver archive sidecar,
   and extracted manifests/checksums/`SUPPORTED_KERNELS.txt`/offline preview.
3. [MATLAB-OFFLINE.md](MATLAB-OFFLINE.md),
   [MATLAB-NVIDIA-ASSETS.json](MATLAB-NVIDIA-ASSETS.json),
   [public preparation receipt](MATLAB-PREPARATION-RECORD-20261102.json),
   [payload checksum list](MATLAB-PAYLOAD-SHA256SUMS) and actual `FETCH-RECEIPT.json`.
4. [ON-SITE-QUICKSTART.md](ON-SITE-QUICKSTART.md) for local media, or
   [INSTALL.md](INSTALL.md) for the full driver procedure;
   [LLM-CONTEXT.md](LLM-CONTEXT.md) for detailed driver implementation context.
5. Target observations and exact release/workload evidence. Resolve differences
   using actual artifact identity and dated receipts; never invent missing facts.

The sealed October 30 archive retains its historical documentation snapshot.
Current source handoff/preparation receipts supersede stale preparation-status
wording inside it without changing its accepted archive bytes or driver release.

## Discovery and integrity commands

The following target queries do not install drivers or enable repositories.
Run on the **GPU target** and retain relevant output privately. An unavailable
command/property is missing evidence, not permission to install/repair blindly.

```bash
cat /etc/redhat-release
uname -m
uname -r
lspci -Dnn -d 10de:
mokutil --sb-state
rpm -q gcc gcc-c++ make kernel-headers
nvidia-smi --query-gpu=index,name,driver_version --format=csv,noheader
cat /sys/module/nvidia/version
cat /proc/driver/nvidia/version
modinfo -F license nvidia
dkms status
```

`/sys/module/nvidia/version` describes the loaded module; `modinfo` can describe
an on-disk module. Compare them rather than treating one as proof of both.
`nvidia-smi`'s displayed CUDA compatibility is not an installed toolkit inventory.
Capture the actual GPU count/edition; do not mechanically pass six to validation.

Set paths to the actual transferred artifacts, then check the driver identity:

```bash
DRIVER_ARCHIVE='/absolute/path/to/nvidia-r580-rhel8-driver-repo-20261030.tar.gz'
DRIVER_BUNDLE='/absolute/path/to/repo-bundle'
printf '%s  %s\n' \
  '7c55e4f252661830ca917949bfda142ddbf7d4f5ade79235b4a09c3e1c1dc8e7' \
  "$DRIVER_ARCHIVE" | sha256sum -c -
(cd "$DRIVER_BUNDLE" && sha256sum -c SHA256SUMS)
TARGET_KERNEL="$(uname -r)"  # GPU target only
grep -Fx "$TARGET_KERNEL" "$DRIVER_BUNDLE/SUPPORTED_KERNELS.txt"
rpm -q "kernel-devel-$TARGET_KERNEL"
```

The final query can report missing devel before installation. Exact availability
in the carried dependencies must then be confirmed by the existing client
procedure. Do not substitute a nearby version or change the target kernel based
on this handoff. Preserve compatible installed userspace headers.

From the source-kit root, verify the cache using standard checksum tools;
**Python is not required** for these checks and is not assumed present on RHEL.

```bash
KIT_ROOT="$PWD"
ADDON_CACHE='/absolute/path/to/matlab-nvidia-addons-20261102'
(cd "$ADDON_CACHE" && sha256sum -c "$KIT_ROOT/docs/MATLAB-PAYLOAD-SHA256SUMS")
# macOS alternative for the same 56-file set:
(cd "$ADDON_CACHE" && shasum -a 256 -c "$KIT_ROOT/docs/MATLAB-PAYLOAD-SHA256SUMS")
```

The optional stager requires **Python 3.9+**; use it on a suitable preparation
host or select an already installed compatible interpreter. Do not replace the
RHEL platform Python. From the source root, plan or verify a writable cache copy:

```bash
python3 scripts/stage-matlab-addons.py  # plan only, no download
python3 scripts/stage-matlab-addons.py --output "$ADDON_CACHE" --verify
```

`--verify` makes no network request but writes a fresh receipt; preserve the
original for history. If artifacts are absent and an authorized connected
staging host is available, use the same helper with `--fetch` instead. It
reserves 2 GiB free space. Optional profiles select only their declared scope;
a single-profile receipt is not all 56 files. A clone/plan is not the payload.

## Proceed and report without widening scope

1. Record actual target facts, intended release/update/products and workflows;
   verify both artifact identities. Preserve the accepted driver release.
2. Establish driver/kernel/open-module/Secure Boot state through the existing
   quickstart/full installation procedure. Continue necessary authorized work;
   explain specific missing evidence if it blocks a dependent action.
3. Install/activate the user's licensed MathWorks media using the matching
   release's offline procedure. Keep releases separate and select explicitly.
4. Test ordinary R2026a supplied-library workflows first. In an idle MATLAB
   session, `run('scripts/matlab_readiness.m')` from the source root inventories
   release/products/compiler/GPU state. See the guide for options and report use.
5. Enable its small numerical/`validateGPU` checks only when those tests are
   intended. The script defaults both off; it neither starts workers, compiles,
   configures a compiler, enables forward compatibility nor writes files.
6. Assemble external SDKs only for selected standalone workflows, following the
   guide's separate-prefix, exact-manifest and isolated RPM-signature procedure.
   TensorRT RPM extraction gives `usr/include`/`usr/lib64`; discovery/adapter,
   relocation/linking/OS dependencies remain untested until proved on target.
7. Build/run representative MEX, standalone and multi-GPU cases as applicable.
   Record compiler/library versions, input/model hashes, precision/tolerance,
   CPU/reference agreement, failures and skipped/blocked workflows.

Do not replace the driver, mix EL9 RPMs, weaken signature/Secure Boot checks,
change network/repository exposure, overwrite MATLAB's supplied libraries, or
add global `LD_LIBRARY_PATH`, `MW_NVCC_PATH` or `/usr/local/cuda` overrides as a
repair. SDK library stubs are for linking and must not enter runtime paths.
Use project-scoped standalone environments described in the guide.

## Acceptance checklist and handback

- [ ] Actual OS/architecture, kernel, GPU edition/count and Secure Boot recorded.
- [ ] Exact carried devel/kernel relationship and approved signing verified;
      580.196.07 loaded open module/driver and GPU health proved after any reboot.
- [ ] Original driver archive and inner checksums verified at destination.
- [ ] Add-on scope/hashes verified; TensorRT signatures and required OS/CUDA
      dependencies separately checked before SDK use.
- [ ] Exact MATLAB release/update/products, license operation, support packages,
      models/data and offline documentation available without unintended downloads.
- [ ] Selected ordinary GPU/deep-learning workflows compared to agreed references.
- [ ] Required MEX/compiler and standalone TensorRT/plain-CUDA workflows tested;
      cuDNN-target gap remains explicitly blocked unless resolved with evidence.
- [ ] R2024 CPU/native-GPU limitations and any separate forward-compatibility
      experiment recorded without promoting it to R2026a/all-toolbox acceptance.
- [ ] Multi-GPU/remote execution validated only if actually required/configured.

Hand back an evidence-based list of **passed / failed / not tested / blocked**
workflows, exact changes/commands, artifact identifiers and remaining next steps.
Never claim all toolboxes, all kernels, target GPU operation or add-on DNF closure
from the preparation tests. Keep license files, credentials and private host
information outside public GitHub documentation and receipts.
