# Download and verify the complete RHEL 8.10 offline kit

## Preferred: one complete XZ payload

[Download `nvidia-r580-rhel8-driver-repo-20261030.tar.xz`](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/download/v2026.10.30-r580.196.07/nvidia-r580-rhel8-driver-repo-20261030.tar.xz), verify and extract:

```bash
printf '%s  %s\n' \
  'f6b127cbd58f0265f6f91978aa61096844007c8b1a7e4eb94c8801fa01503db5' \
  'nvidia-r580-rhel8-driver-repo-20261030.tar.xz' | sha256sum -c -
tar -xJf nvidia-r580-rhel8-driver-repo-20261030.tar.xz
(cd repo-bundle && sha256sum -c SHA256SUMS)
```

The XZ archive is **2,024,025,344 bytes** (1.89 GiB) and contains the
complete **617-RPM** kit and all **104 exact stock kernel alternatives**.
See [SINGLE-FILE-DOWNLOAD.md](SINGLE-FILE-DOWNLOAD.md) and
[XZ-TRANSPORT-RECORD-20261102.json](XZ-TRANSPORT-RECORD-20261102.json).
GitHub's automatic source ZIP/TAR contains tooling rather than the binary kit.

To download only the preferred archive and its small SHA-256 sidecar:

```bash
gh release download v2026.10.30-r580.196.07 \
  --repo BenjaminSisko/nvidia-r580-rhel8-airgap \
  --dir nvidia-rhel8-xz-download \
  --pattern nvidia-r580-rhel8-driver-repo-20261030.tar.xz \
  --pattern nvidia-r580-rhel8-driver-repo-20261030.tar.xz.sha256
cd nvidia-rhel8-xz-download
sha256sum -c nvidia-r580-rhel8-driver-repo-20261030.tar.xz.sha256
tar -xJf nvidia-r580-rhel8-driver-repo-20261030.tar.xz
(cd repo-bundle && sha256sum -c SHA256SUMS)
```

The reported LZMA2 dictionary is 128 MiB; decoding needs about **129 MiB** plus tar/process overhead. This uses standard XZ/LZMA2 with CRC64, supported by RHEL 8's `xz` 5.2.4. Confirm that tar and xz are available on the machine used for extraction.
The decoded tar's **4,628,807,680 bytes** and SHA-256 `b3214b0109f825276f7cd9b6f90c0df390d7f6aebdbaf6f0ef0603c2ed104bac` match the
original gzip-decoded tar exactly. All 654 included file checksums remain the
same; no RPM, kernel alternative, metadata or payload file was changed.

## Fallback: original gzip in two ordered byte parts

The [release](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/tag/v2026.10.30-r580.196.07) retains all original ten assets unchanged. Its original
archive is **2,632,185,106 bytes**, larger than the single-asset limit, so that
gzip transport remains split. Download only those ten files into a new folder;
this excludes the four XZ additions and keeps the old helper's asset set exact:

```bash
gh release download v2026.10.30-r580.196.07 \
  --repo BenjaminSisko/nvidia-r580-rhel8-airgap \
  --dir nvidia-rhel8-gzip-download \
  --pattern BUILD-RECORD.json \
  --pattern DOWNLOAD-AND-VERIFY.md \
  --pattern MANIFEST.txt \
  --pattern ON-SITE-QUICKSTART.md \
  --pattern RELEASE-SHA256SUMS.txt \
  --pattern SUPPORTED_KERNELS.txt \
  --pattern nvidia-r580-rhel8-driver-repo-20261030.tar.gz.part-aa \
  --pattern nvidia-r580-rhel8-driver-repo-20261030.tar.gz.part-ab \
  --pattern nvidia-r580-rhel8-driver-repo-20261030.tar.gz.sha256 \
  --pattern reassemble-release.sh
cd nvidia-rhel8-gzip-download
bash reassemble-release.sh
```

The helper works on Linux/macOS, verifies the original asset checksums, joins
`part-aa` followed by `part-ab`, checks the original archive's pinned SHA-256,
and preserves an existing archive unless it already verifies. The parts are
not individual tar archives.

Manual original-gzip reassembly on Linux:

```bash
sha256sum -c RELEASE-SHA256SUMS.txt
cat nvidia-r580-rhel8-driver-repo-20261030.tar.gz.part-aa \
    nvidia-r580-rhel8-driver-repo-20261030.tar.gz.part-ab \
  > nvidia-r580-rhel8-driver-repo-20261030.tar.gz
sha256sum -c nvidia-r580-rhel8-driver-repo-20261030.tar.gz.sha256
tar -xzf nvidia-r580-rhel8-driver-repo-20261030.tar.gz
(cd repo-bundle && sha256sum -c SHA256SUMS)
```

Original gzip SHA-256:

```text
7c55e4f252661830ca917949bfda142ddbf7d4f5ade79235b4a09c3e1c1dc8e7
```

On macOS, replace `sha256sum -c` with `shasum -a 256 -c`. All 654 inner checksums
must pass. Extracted regular-file bytes total **4,628,279,520**. Retaining the
gzip parts, joined gzip and extracted tree needs about 10 GB free; the XZ path
avoids those duplicate gzip transport copies.

## Use the verified payload

Read `repo-bundle/docs/ON-SITE-QUICKSTART.md` for optional local `file://` repos,
or the full included INSTALL guide. This driver-only kit carries both
repositories, all selected NVIDIA/RHEL/EPEL driver/build/runtime RPMs and
kernel development alternatives. It contains no CUDA Toolkit or MATLAB media.
No credentials, subscription client certificates, private keys or private
build-evidence folder are included. Vendor RPM licenses/terms are retained.

The tar stream preserves its verified October 30 snapshot. Current release
records/download instructions supersede stale prepublication prose inside it;
the sealed payload bytes are unchanged. The old offline RPM test used the
latest carried kernel pair. Target DKMS compilation, Secure Boot, actual GPU
edition/count and application acceptance remain on-site work. The separate
MATLAB CUDA/TensorRT cache is not part of either driver transport.
