# Instructions for an LLM working with this repository

Read [docs/LLM-HANDOFF.md](docs/LLM-HANDOFF.md) first. It is the starting point
for explaining the complete prepared driver kit and the separate MATLAB
development supplement to an operator or another assistant.

Then read the records appropriate to the work:

1. `docs/BUILD-RECORD-20261030.md` and `docs/GITHUB-DOWNLOAD.md` for the published
   RHEL 8.10 driver kit.
2. `docs/MATLAB-PREPARATION-RECORD-20261102.json`,
   `docs/MATLAB-NVIDIA-ASSETS.json` and `docs/MATLAB-PAYLOAD-SHA256SUMS` for the
   verified NVIDIA add-on file snapshot and its exact pins.
3. `docs/ON-SITE-QUICKSTART.md`, `docs/INSTALL.md`, `docs/LLM-CONTEXT.md` and
   `docs/MATLAB-OFFLINE.md` for the relevant procedure, followed by the actual
   transported manifests, receipts and target evidence.

## Evidence and scope

- The target is RHEL 8.10 x86_64 with RTX PRO 6000 Blackwell GPUs. The actual
  kernel, card edition/count, Secure Boot state and installed software remain
  unknown until inspected. Six GPUs is an earlier configurable default.
- The published driver kit is 617 RPMs and 104 exact stock kernel development
  pairs. Preserve its immutable archive/tag; use the pinned 580.196.07 open
  DKMS driver and exact target `kernel-devel` selection.
- The separate MATLAB supplement is 33 CUDA 12.8.2 archives plus 23 TensorRT
  10.9.0.34/CUDA 12.8 RPMs. Its 56 vendor file hashes passed. That does not prove
  RPM signatures, RHEL dependency closure, installation or MATLAB execution.
- R2026a is the primary MATLAB release. R2024a/b is a conditional legacy case.
  Preserve the external cuDNN compatibility gap described in the handoff.
  Planning for all toolboxes is not evidence that every workflow is supported.
- MATLAB installers, licensed products, support packages, models and activation
  material are separate MathWorks media. Their presence is not established.
- Keep binaries outside source Git. The existing driver release contains the
  driver binaries; the MATLAB add-on binaries are a separate local folder,
  reproducible through the pinned downloader. The source ZIP contains tooling.
- Treat source snapshots as preparation evidence and target observations as
  installation/runtime evidence. Report conflicts and missing proof explicitly.
  Do not infer installed versions from a filename or from `nvidia-smi`'s CUDA
  compatibility label.

Proceed within the user's authorized scope. Gather available read-only facts
before operations that depend on unknown target state. Preserve MATLAB's
supplied libraries, the existing driver, and the separation between ordinary
MATLAB GPU use and standalone CUDA development.

## Verification when changing files

For documentation edits, check links, code-block syntax, and stated versions,
counts, sizes and hashes against the recorded manifests. For script changes,
also run the relevant tests and the repository's required CI checks. Do not
describe source tests as GPU, DKMS or MATLAB workload acceptance. Exclude
credentials, license files, private keys and private target reports from Git.
