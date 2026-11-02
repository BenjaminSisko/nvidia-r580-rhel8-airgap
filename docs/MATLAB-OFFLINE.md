# MATLAB on the RHEL 8.10 Blackwell system

Reviewed November 2, 2026. Use **R2026a as the primary MATLAB release** for
native Blackwell GPU computing. Keep the accepted **580.196.07 Open-DKMS driver**
and October 30 **617-RPM driver bundle/release unchanged**. This guide adds
workflow prerequisites and a separate NVIDIA development-artifact cache; it
does not establish that every toolbox or application has passed on the target.

RHEL 8.10 meets the RHEL 8 minimum of 8.6 listed for
[R2026a](https://www.mathworks.com/content/dam/mathworks/mathworks-dot-com/support/sysreq/files/system-requirements-release-2026a-linux.pdf),
[R2024a](https://www.mathworks.com/content/dam/mathworks/mathworks-dot-com/support/sysreq/files/system-requirements-release-2024a-linux.pdf)
and [R2024b](https://www.mathworks.com/content/dam/mathworks/mathworks-dot-com/support/sysreq/files/system-requirements-release-2024b-linux.pdf).
That is OS support, separate from GPU and workflow support. Some products are
unavailable on Linux: for example, Data Acquisition Toolbox and Spreadsheet
Link; the R2024 lists also exclude Model-Based Calibration Toolbox. Interpret
“all toolboxes” as all **licensed, Linux-supported products needed by the
workloads**, with their separate data, models and support packages.

## Choose the workflow before installing NVIDIA add-ons

| Workflow | MATLAB-side prerequisites | Separate NVIDIA toolkit/library requirement |
|---|---|---|
| `gpuArray`, GPU-enabled MATLAB/toolbox functions | MATLAB + Parallel Computing Toolbox (PCT); each called function must support GPU arrays | MATLAB supplies its GPU libraries. A working compatible NVIDIA driver is required; an external toolkit is not a blanket prerequisite. |
| Deep Learning Toolbox training/prediction inside MATLAB | Deep Learning Toolbox + PCT for GPU execution; required model/importer packages | Use the libraries supplied with the MATLAB release. External cuDNN/TensorRT does not replace them. |
| Custom `.cu` MEX with `mexcuda` | PCT + supported host C++ compiler | MATLAB supplies `nvcc` and its CUDA libraries; external dependencies are needed only for the custom code's additional libraries. |
| GPU Coder MEX / supported GPU Simulink simulation | GPU Coder, MATLAB Coder, PCT; Simulink/Simulink Coder for model generation; deep-learning products/packages as applicable | Uses MATLAB's supplied NVIDIA tools/libraries. TensorRT integration has a separate MathWorks installation step. |
| GPU Coder standalone source/library/executable | Above code-generation products, supported host compiler and an application-specific build/test | R2026a: latest CUDA **12.8** update, selected here as **12.8.2**; TensorRT **10.9** for that target library; cuDNN target has the blocker below. |
| Multiple GPUs / cluster execution | Appropriate PCT execution strategy and, for remote workers, MATLAB Parallel Server/licensing and site configuration | GPU count alone does not distribute a single MATLAB operation. Validate the intended worker/device mapping separately. |

See [R2026a GPU requirements](https://www.mathworks.com/help/releases/R2026a/parallel-computing/gpu-computing-requirements.html),
[CUDA MEX workflow](https://www.mathworks.com/help/releases/R2026a/parallel-computing/run-mex-functions-containing-cuda-code.html)
and [GPU Coder toolchain setup](https://www.mathworks.com/help/releases/R2026a/gpucoder/gs/setting-up-the-toolchain.html).
The distinction is important: installing a newer toolkit into `/opt` or a user
prefix does not upgrade the CUDA/cuDNN libraries inside an older MATLAB.

## Compatibility decisions and a cuDNN blocker

[R2026a GPU Coder prerequisites](https://www.mathworks.com/help/releases/R2026a/gpucoder/gs/install-prerequisites.html)
list CUDA 12.8's latest update, cuDNN 8.9 and TensorRT 10.9. The independent
NVIDIA add-on selects CUDA **12.8.2** from NVIDIA's
[versioned redistributable manifest](https://developer.download.nvidia.com/compute/cuda/redist/redistrib_12.8.2.json)
and TensorRT **10.9.0.34 for CUDA 12.8**. The pinned driver 580.196.07 is above
the R2026a CUDA 12.8 Linux minimum of 570.26; preserve it. The CUDA version
printed by `nvidia-smi` describes the driver's CUDA compatibility, not which
standalone toolkit or MATLAB-supplied runtime is installed.

**Standalone GPU Coder `cudnn` generation on Blackwell is unresolved.** The
MathWorks external-library row specifies cuDNN 8.9, while NVIDIA introduced
compute capability 10.0/12.0 support in
[cuDNN 9.7](https://docs.nvidia.com/deeplearning/cudnn/backend/v9.7.0/release-notes.html).
The [9.7.1 matrix](https://docs.nvidia.com/deeplearning/cudnn/backend/v9.7.1/reference/support-matrix.html)
qualifies Blackwell with CUDA 12.8. Consequently, cuDNN 8.9 is not a native
Blackwell solution, and silently substituting cuDNN 9.7+ would leave the
MathWorks-tested version combination. No such substitution is performed or
accepted by this project. Obtain a supported combination from MathWorks for a
required cuDNN-target workflow; keep its acceptance pending until then. This
external code-generation issue does not override R2026a's documented native
GPU support for computations using its supplied libraries.

For supported networks, the documented alternative is **plain CUDA generation
without third-party deep-learning libraries**. Configure the selected project,
then run its own code-generation and numerical acceptance tests separately:

```matlab
cfg = coder.gpuConfig('lib');
cfg.DeepLearningConfig = coder.DeepLearningConfig(TargetLibrary='none');
% Supply the project's entry point, input types and generation arguments.
% This configuration alone does not compile or prove the application.
```

`TargetLibrary='none'` avoids external cuDNN/TensorRT dependence for supported
layers; it still requires the CUDA build environment for standalone output.
Layer support, precision, performance and CPU/GPU numerical agreement need
validation. See [plain CUDA deep learning generation](https://www.mathworks.com/help/releases/R2026a/gpucoder/ug/code-generation-for-deep-learning-networks.html)
and [target-library configuration](https://www.mathworks.com/help/releases/R2026a/gpucoder/ref/coder.deeplearningconfig.html).

For TensorRT-backed MEX/simulation, R2026a directs users to
[`gpucoder.installTensorRT`](https://www.mathworks.com/help/releases/R2026a/gpucoder/ref/gpucoder.installtensorrt.html),
which launches its MathWorks installer and can restart MATLAB. Stage the
release-specific MathWorks integration package for offline use. The separate
NVIDIA RPM cache below is the standalone SDK; merely extracting those RPMs does
not complete the MathWorks Add-On installation.

## R2024a and R2024b are separate compatibility cases

Both archived GPU requirement pages support compute capabilities **5.0–9.x**:
[R2024a](https://www.mathworks.com/help/releases/R2024a/parallel-computing/gpu-computing-requirements.html),
[R2024b](https://www.mathworks.com/help/releases/R2024b/parallel-computing/gpu-computing-requirements.html).
Their GPU Coder prerequisite pages list tested CUDA versions through **12.2**,
cuDNN **8.9**, and TensorRT **8.6.1**:
[R2024a](https://www.mathworks.com/help/releases/R2024a/gpucoder/gs/install-prerequisites.html),
[R2024b](https://www.mathworks.com/help/releases/R2024b/gpucoder/gs/install-prerequisites.html).
Neither has native Blackwell GPU support. Keep either release in its own
installation directory and select its executable explicitly; CPU workflows
may still be relevant.

MATLAB offers forward compatibility for newer GPUs, but MathWorks warns that
it can produce wrong results or unexpected behavior. It is a **separately
reviewed experiment**, not an accepted replacement for R2026a. Do not enable it
in `startup.m`, shell profiles or shared environment settings for this task.
If required later, use a disposable test session, agreed reference data and
per-workflow numerical tolerances, then record failures/skipped features.
The [forward-compatibility documentation](https://www.mathworks.com/help/releases/R2024b/parallel-computing/parallel.gpu.enablecudaforwardcompatibility.html)
describes this limit. This project's diagnostic only queries the current flag.

Do not point R2024 `MW_NVCC_PATH` at CUDA 12.8 or globally prepend toolkit
libraries with `LD_LIBRARY_PATH` as a GPU-support workaround. Existing MEX
binaries and application libraries require their own Blackwell/PTX review and
rebuild/testing plan; NVIDIA's
[Blackwell compatibility guide](https://docs.nvidia.com/cuda/archive/12.8.2/blackwell-compatibility-guide/index.html)
explains why a sufficiently new driver alone does not provide missing GPU code.

## Host compiler: use the supported existing baseline first

The MathWorks Linux compiler tables list GCC **8.x–13.x** for R2026a/R2024b and
**8.x–12.x** for R2024a for the relevant MATLAB/MATLAB Coder/GPU Coder columns:
[R2026a compiler table](https://www.mathworks.com/content/dam/mathworks/mathworks-dot-com/support/sysreq/files/system-requirements-release-2026a-supported-compilers.pdf),
[R2024b](https://www.mathworks.com/content/dam/mathworks/mathworks-dot-com/support/sysreq/files/system-requirements-release-2024b-supported-compilers.pdf),
[R2024a](https://www.mathworks.com/content/dam/mathworks/mathworks-dot-com/support/sysreq/files/system-requirements-release-2024a-supported-compilers.pdf).
CUDA 12.8.2 qualifies RHEL 8.10 with GCC 8.5 and allows GCC 6.x–14.x in its
host-compiler range. See the [CUDA 12.8.2 Linux guide](https://docs.nvidia.com/cuda/archive/12.8.2/cuda-installation-guide-linux/index.html).

Thus RHEL 8.10 **GCC/G++ 8.5** is a reasonable supported baseline for MEX/GPU
Coder; no automatic GCC Toolset upgrade is required. The original driver
bundle carries GCC/G++ dependencies. Confirm what is installed on the actual
host before a build:

```bash
rpm -q gcc gcc-c++ make glibc glibc-devel libstdc++ libstdc++-devel
gcc --version
g++ --version
```

In the intended MATLAB release, inspect/select the supported compiler using
`mex -setup C++`, then perform an application-specific MEX build when ready.
The readiness script inspects the current selection without changing it.
TensorRT/static CUDA linkage, additional languages and third-party toolboxes can
have further linker/compiler requirements; the baseline check is not acceptance
of every static-link or external-library workflow.

## Prepare licensed MathWorks media separately

The NVIDIA cache contains no MATLAB installer, toolbox licenses, activation
files, proprietary model weights or MathWorks support-package payloads. Before
the visit, prepare a separate **Linux x86_64** media set for each exact release
and update level. A Mac download machine must still select the Linux target.
Use the [R2026a download-only procedure](https://www.mathworks.com/help/releases/R2026a/install/ug/download-without-installing.html),
[offline installation](https://www.mathworks.com/help/releases/R2026a/install/ug/install-using-a-file-installation-key.html)
and [offline support-package procedure](https://www.mathworks.com/help/releases/R2026a/install/ug/install-support-packages-on-offline-computer.html).
Use the corresponding archived pages when preparing R2024 media.

- Download all entitled Linux product files, the installer and chosen update;
  obtain any required File Installation Key/license file/activation through the
  license administrator. Keep license material outside Git and public receipts.
- Include MATLAB, PCT, Deep Learning Toolbox, MATLAB Coder and GPU Coder for the
  relevant workflows. Include Simulink, Simulink Coder and other licensed
  products actually used by models. Product installation does not prove license
  availability at runtime.
- Stage **GPU Coder Interface for Deep Learning** when generating deep-learning
  code; separately stage the TensorRT integration package if using that path.
  Obtain model-specific importer/converter packages, pretrained-network assets,
  example data, Python environments and other external dependencies used by the
  real projects. Record versions and hashes; test with networking disconnected.
- For support packages, configure MathWorks `mpm`'s release-specific input file
  and `platform.glnxa64`, download on a connected machine, then transfer the
  complete folder and install from its local source per the linked procedure.
  Do not assume Add-On Explorer can fetch missing material at the site.
- Include matching offline documentation. Test license operation with the
  intended offline licensing arrangement. If a license server is needed, its
  existing approved connectivity must be verified separately.
- NVIDIA Jetson/DRIVE support, JetPack, cross-compilers and board packages are
  needed only if those embedded targets are actually involved. Do not add them
  merely because the machine has desktop/server NVIDIA GPUs.

## Stage and verify the separate NVIDIA add-on cache

[MATLAB-NVIDIA-ASSETS.json](MATLAB-NVIDIA-ASSETS.json) pins complete vendor
artifacts: 33 CUDA 12.8.2 `linux-x86_64` component archives (**4,253,511,164
bytes**) and 23 TensorRT 10.9.0.34/CUDA 12.8 RHEL8 RPMs (**5,063,946,188 bytes**).
The combined download is **9,317,457,352 bytes**, before extraction or any
MathWorks media. This is an artifact cache, **not a solved RHEL DNF repository**.
Disk space is also needed for extracted components, SDKs and build output.

From the source-project directory, print the plan, fetch and then verify:

```bash
python3 scripts/stage-matlab-addons.py
python3 scripts/stage-matlab-addons.py \
  --output dist/matlab-nvidia-addons-20261102 --fetch
python3 scripts/stage-matlab-addons.py \
  --output dist/matlab-nvidia-addons-20261102 --verify
```

`--fetch` verifies pinned NVIDIA size/SHA-256 before accepting each artifact;
`--verify` works without network access. The helper retains a 2 GiB free-space
reserve and does not install or extract anything. It writes a receipt and local
checksum manifest only after the selected set passes. To carry a single SDK,
use `--profile cuda-12.8.2` or `--profile tensorrt-10.9.0.34-cuda12.8` on each
command; retain the corresponding scope in the receipt. Missing files or a
failed receipt mean the selected cache is not complete.

Transfer the entire verified output and matching helper/source manifest. On the
offline machine, rerun `--verify --output /absolute/path/to/cache` and, from that
cache directory, `sha256sum -c SHA256SUMS`. Check the actual `FETCH-RECEIPT.json`
for completion; documentation alone is not a download or target-test receipt.
CUDA archives retain their per-component licenses. The selected set excludes
the driver, Fabric Manager, IMEX, `nvidia_fs` and NVSwitch libraries: it cannot
replace the accepted driver. Do not use a `cuda`/driver metapackage or a runfile
that installs another driver.

## Assemble CUDA in a separate prefix only when standalone builds need it

NVIDIA's [component archive documentation](https://docs.nvidia.com/cuda/archive/12.8.2/cuda-installation-guide-linux/index.html#tarball-and-zip-archive-deliverables)
explains that redistributable archives are not installers, and provides an
[official example merger](https://github.com/NVIDIA/build-system-archive-import-examples/blob/main/parse_redist.py).
Review its options/selected components before use; do not let another downloader
silently expand this project's filtered set. The following operator recipe
merges the already-verified CUDA components into a **new user-owned prefix** on
the Linux target. It retains each complete component (including licenses) and
stops on conflicting toolkit files. Top-level directories are merged; original
root metadata/license files remain in their component trees. It does not run
on staging automatically.
Use a filesystem with enough space for both component and merged trees.

```bash
CUDA_CACHE='/absolute/path/to/matlab-nvidia-addons-20261102'
CUDA_PREFIX="$HOME/opt/nvidia/cuda-12.8.2"
python3 - "$CUDA_CACHE" "$CUDA_PREFIX" <<'PY'
import filecmp, json, os, shutil, subprocess, sys
from pathlib import Path
cache, prefix = map(lambda p: Path(p).absolute(), sys.argv[1:])
if prefix.exists() or prefix.is_symlink():
    raise SystemExit('Choose a new prefix; do not overlay a previous install')
parts = prefix.parent / (prefix.name + '-components')
if parts.exists() or parts.is_symlink():
    raise SystemExit('Choose a new component directory')
manifest = json.loads((cache / 'ASSET-MANIFEST.json').read_text())
assets = [a for a in manifest['assets'] if a['profile'] == 'cuda-12.8.2']
if len(assets) != 33:
    raise SystemExit('Unexpected CUDA component set; review the pinned manifest')
prefix.mkdir(parents=True); parts.mkdir()
def merge(src, dst):
    exists = dst.exists() or dst.is_symlink()
    if src.is_symlink():
        if exists:
            if not dst.is_symlink() or os.readlink(src) != os.readlink(dst):
                raise RuntimeError('Conflicting symlink: ' + str(dst))
        else:
            dst.symlink_to(os.readlink(src))
    elif src.is_dir():
        if exists and (dst.is_symlink() or not dst.is_dir()):
            raise RuntimeError('Conflicting directory: ' + str(dst))
        dst.mkdir(exist_ok=True)
        for child in src.iterdir():
            merge(child, dst / child.name)
    elif exists:
        if dst.is_symlink() or not dst.is_file() or not filecmp.cmp(src, dst, shallow=False):
            raise RuntimeError('Conflicting file: ' + str(dst))
    else:
        shutil.copy2(src, dst)
for asset in assets:
    component = parts / asset['component']; component.mkdir()
    subprocess.run(['tar', '-xJf', str(cache / 'payload' / asset['filename']),
        '--strip-components=1', '--no-same-owner', '--no-same-permissions',
        '-C', str(component)], check=True)
    for item in component.iterdir():
        if item.is_dir() or item.is_symlink():
            merge(item, prefix / item.name)
if (prefix / 'lib').is_dir() and not (prefix / 'lib64').exists():
    (prefix / 'lib64').symlink_to('lib')
print('Assembled toolkit; component licenses retained at', parts)
PY
"$CUDA_PREFIX/bin/nvcc" --version
```

Run the cache verification immediately before assembly; use only this pinned
vendor set. Stop and inspect any conflict rather than overwriting. Retain the
component directory and manifest with the prefix. Confirm `bin/nvcc`,
`include/cuda.h`, real runtime libraries and `nvvm/libdevice` exist. No target
assembly/compilation is claimed until its own operator receipt is recorded.
Do not place `lib/stubs` or `lib64/stubs` on a runtime search path; these are
link-time placeholders, not the working NVIDIA driver.

## TensorRT extraction and standalone environment

The TensorRT cache carries the complete pinned RHEL8 vendor RPM set, including
runtime/development/static libraries, headers, plugins/parsers, samples and
bindings. Python bindings are not required just to call generated C++ inference;
carrying them does not select or install a Python environment. Cache hashes are
not a substitute for verifying RPM signatures with the independently checked
NVIDIA public key. Use an isolated RPM trust database if the key is not already
approved; do not import a new key system-wide merely for extraction. All target
EL8 ABI and OS/library dependencies still need inspection and a real build/test.

After verifying the original driver bundle, its provided NVIDIA public key can
be checked and used in a disposable RPM database. Run on Linux; this does not
modify the host RPM database:

```bash
BUNDLE='/opt/nvidia-rhel8/repo-bundle'
CUDA_CACHE='/absolute/path/to/matlab-nvidia-addons-20261102'
(
  set -euo pipefail
  trust_dir="$(mktemp -d)"
  trap 'rm -rf "$trust_dir"' EXIT
  mkdir -m 700 "$trust_dir/gpg" "$trust_dir/rpm"
  fingerprint="$(gpg --homedir "$trust_dir/gpg" --show-keys --with-colons \
    --fingerprint "$BUNDLE/NVIDIA-GPG-KEY-D42D0685.pub" 2>/dev/null | \
    awk -F: '$1=="fpr" {print toupper($10); exit}')"
  test "$fingerprint" = '610C7B14E068A878070DA4E99CD0A493D42D0685'
  rpm --dbpath "$trust_dir/rpm" --initdb
  rpm --dbpath "$trust_dir/rpm" --import "$BUNDLE/NVIDIA-GPG-KEY-D42D0685.pub"
  for package in "$CUDA_CACHE"/payload/*.rpm; do
    rpmkeys --dbpath "$trust_dir/rpm" --checksig "$package"
  done
)
```

Require every package to report valid digests/signatures with that approved key;
a missing key/signature is a failure. A private-prefix extraction preserves
host RPM registration and the driver.
The following is an operator action on the offline Linux machine; it requires
`rpm2cpio`/`cpio` and a verified complete cache. Do not run it as root:

```bash
TRT_SDK="$HOME/opt/nvidia/tensorrt-10.9.0.34-rhel8"
# Set CUDA_CACHE to the verified cache above; inspect this exact list first.
find "$CUDA_CACHE/payload" -maxdepth 1 -name '*.rpm' -type f -print | sort
(
  set -euo pipefail
  test ! -e "$TRT_SDK" && test ! -L "$TRT_SDK"
  mkdir -p "$TRT_SDK"
  for package in "$CUDA_CACHE"/payload/*.rpm; do
    rpm2cpio "$package" | (cd "$TRT_SDK" && cpio -idm --no-absolute-filenames)
  done
)
```

The verified vendor file lists place `NvInfer.h` under `usr/include`, runtime
and linker libraries under `usr/lib64`, and `trtexec` under
`usr/src/tensorrt/bin` below `TRT_SDK`; they are not installed into `/usr`.
MathWorks illustrates an SDK root with `include` and `lib`, so do not assume
`NVIDIA_TENSORRT="$TRT_SDK/usr"` automatically handles `lib64`. A project-owned
adapter root with `include` pointing to the extracted `usr/include` and `lib`
pointing to `usr/lib64` can be evaluated; GPU Coder discovery, relocation,
linking and a real inference remain pending until tested. Use the actual
`usr/lib64` for a standalone process's runtime library path. A raw extracted
RPM tree is not a tested relocatable SDK installer. A native DNF install is an alternative only
with the separately reviewed complete OS/CUDA dependencies and a transaction
preview proving no driver replacement. This project does not supply that DNF
closure for the add-on.

Set CUDA/TensorRT paths only in a **standalone project's process/environment**.
For example, after inspecting the actual private SDK layout, pass the toolkit
`bin` and real CUDA/TensorRT library directories to that project's launch/build
wrapper; use `NVIDIA_TENSORRT` where GPU Coder requests the SDK root. Do not edit
`/etc/ld.so.conf`, create a global `/usr/local/cuda` link, modify MATLAB's supplied
libraries, or add global `LD_LIBRARY_PATH`/`MW_NVCC_PATH` entries. A fresh normal
MATLAB launch should continue to use its supplied libraries. GPU Coder's
[environment setup](https://www.mathworks.com/help/releases/R2026a/gpucoder/gs/setting-up-the-toolchain.html)
describes the standalone library roots and optional `coder.checkGpuInstall`
checks; those checks can build/run tests and are deliberately outside the
lightweight diagnostic.

## Run the lightweight diagnostic in each MATLAB release

Start a fresh MATLAB session without other active GPU work. Set the source-kit
path, then run the included valid MATLAB script filename:

```matlab
kit = '/absolute/path/to/nvidia-r580-rhel8-airgap';
matlabReadinessOptions = struct('RunSmallTest',false, 'RunValidateGPU',false);
run(fullfile(kit,'scripts','matlab_readiness.m'));
matlabReadinessReport
```

Default behavior records release/version, `ver` products, installed add-on
names/versions, Linux distribution/kernel, architecture, selected compiler
metadata and PCT GPU inventory. It reports missing products, unavailable GPUs,
count mismatch (if an expected count is supplied), existing environment-override
presence and current forward-compatibility state. It does not copy usernames,
hostnames, IPs, license identifiers, environment values or raw error messages.
It writes no files, configures no compiler, downloads nothing and starts no
workers or code-generation build. Enumeration can initialize the driver and
require a PCT license. Product presence is not license or function acceptance.

For an explicit small **current/default GPU** comparison and optional
`validateGPU` (available from R2024b), rerun with:

```matlab
matlabReadinessOptions.RunSmallTest = true;
matlabReadinessOptions.RunValidateGPU = true;
% Set only after the actual card count is confirmed; six is a prior assumption.
% matlabReadinessOptions.ExpectedGPUCount = 6;
run(fullfile(kit,'scripts','matlab_readiness.m'));
```

The small test compares a deterministic 64×64 double matrix product against
CPU results; its tolerance/result are in `smallTest`. `validateGPU` checks the
current/default device and may take longer. The script counts its reported
passed/failed/skipped checks without retaining raw local diagnostic text; if
output cannot be parsed it reports that explicitly. Failures that do not throw
exceptions are not silently accepted. To diagnose further, run `validateGPU`
manually and review the output locally. A passing small test does not validate
other GPUs, deep-learning layers, generated code or every toolbox. See the
[validateGPU documentation](https://www.mathworks.com/help/releases/R2026a/parallel-computing/validategpu.html).

If desired, save the resulting report explicitly to a private evidence location:

```matlab
save('matlab-readiness-report.mat','matlabReadinessReport');
```

Record each release/update, observed GPU edition/count and 580.196.07 driver,
representative toolbox workflows, model/data versions, numerical tolerances,
compiler/MEX build, generated-code target and multi-GPU strategy. Mark individual
workflows **passed / failed / not tested / blocked**. Keep the cuDNN-target
blocker and R2024 forward-compatibility case explicit; neither becomes accepted
because another toolbox's GPU operation passed.
