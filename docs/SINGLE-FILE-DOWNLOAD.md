# Download the complete driver kit as one XZ file

[Download `nvidia-r580-rhel8-driver-repo-20261030.tar.xz`](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/download/v2026.10.30-r580.196.07/nvidia-r580-rhel8-driver-repo-20261030.tar.xz)
(**2,024,025,344 bytes**, 1.89 GiB), then verify and extract on Linux:

```bash
printf '%s  %s\n' \
  'f6b127cbd58f0265f6f91978aa61096844007c8b1a7e4eb94c8801fa01503db5' \
  'nvidia-r580-rhel8-driver-repo-20261030.tar.xz' | sha256sum -c -
tar -xJf nvidia-r580-rhel8-driver-repo-20261030.tar.xz
(cd repo-bundle && sha256sum -c SHA256SUMS)
```

The first command uses the pinned XZ SHA-256 directly, so the large payload is
one browser download. Its optional [checksum sidecar](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/download/v2026.10.30-r580.196.07/nvidia-r580-rhel8-driver-repo-20261030.tar.xz.sha256)
can instead be checked with `sha256sum -c nvidia-r580-rhel8-driver-repo-20261030.tar.xz.sha256`.
On macOS, use `shasum -a 256 -c` for checksum verification; an XZ-capable tar/xz
is required for extraction. Read `repo-bundle/docs/ON-SITE-QUICKSTART.md` next.

The [same release](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/tag/v2026.10.30-r580.196.07) also offers GitHub CLI download of just this
archive and its small checksum sidecar:

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

## What changed, and the proof

Only the outer transport compression changed. All **617 RPMs**, **104 exact
stock RHEL 8.10 kernel development/header pairs**, metadata, helpers, documentation
and all **654 inner checksums** are the accepted October 30 driver payload.
Driver **580.196.07 Open-DKMS** remains pinned. No RPM, kernel alternative or
payload file was removed, regenerated or repacked.

The original gzip was verified at `2026-11-02T23:09:28.383159+00:00`.
XZ verification finished at `2026-11-02T23:26:13.925802+00:00`. The original gzip-decoded
tar stream and the XZ-decoded tar stream both have **4,628,807,680 bytes** and
SHA-256 `b3214b0109f825276f7cd9b6f90c0df390d7f6aebdbaf6f0ef0603c2ed104bac`. Equal length and SHA-256 establish the exact same raw tar
stream, including its original entries and metadata. The XZ archive has its
own SHA-256 above; it is not expected to equal the gzip archive hash.
See [the sanitized transport record](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/download/v2026.10.30-r580.196.07/XZ-TRANSPORT-RECORD.json).

The reported LZMA2 dictionary is 128 MiB; decoding needs about **129 MiB** plus tar/process overhead. This uses standard XZ/LZMA2 with CRC64, supported by RHEL 8's `xz` 5.2.4. Confirm that tar and xz are available on the machine used for extraction.
Allow additional disk space for the extracted repositories; extracted regular
file bytes remain **4,628,279,520**. Extract into a new directory.

## Existing gzip fallback remains available

The original `nvidia-r580-rhel8-driver-repo-20261030.tar.gz` stays as its two ordered `part-aa`/`part-ab` release
assets, **2,632,185,106 bytes** when joined, SHA-256
`7c55e4f252661830ca917949bfda142ddbf7d4f5ade79235b4a09c3e1c1dc8e7`. Follow [GITHUB-DOWNLOAD.md](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/blob/main/docs/GITHUB-DOWNLOAD.md) for the original
helper/reassembly procedure. The original ten assets are retained unchanged;
the XZ file, its sidecar, `XZ-TRANSPORT-RECORD.json` and this guide are four
additions to that release.

The target kernel, GPU edition/count and Secure Boot state remain unknown.
This transport check adds no DKMS, GPU or MATLAB acceptance. The independent
CUDA/TensorRT MATLAB supplement remains separate from this driver-only kit.
