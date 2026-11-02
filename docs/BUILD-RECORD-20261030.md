# RHEL 8.10 Blackwell offline kit — verified build, October 30, 2026

The completed local transport is **`nvidia-r580-rhel8-driver-repo-20261030.tar.gz`**, with **104 exact stock RHEL 8.10 kernel development/header pairs**. The kit uses NVIDIA **580.196.07**, `nvidia-driver:580-open`, and Open-DKMS. It detects the target's running kernel; it carries alternatives without installing another kernel image.

| Result | Verified value |
|---|---|
| Archive size | 2,632,185,106 bytes (2.63 GB / 2.45 GiB) |
| Extracted file bytes | 4,628,279,520 bytes (4.63 GB / 4.31 GiB) |
| Kernel range | `4.18.0-553.el8_10.x86_64` through `4.18.0-553.180.1.el8_10.x86_64` |
| Signed RPMs | 23 NVIDIA + 594 Red Hat/EPEL = 617 |
| Local transport check | Archive SHA-256 and all 654 included per-file checksums passed |
| Kernel files | All 104 exact development/header pairs verified present |
| Offline dependency test | Two delivered file repositories only; 410-package transaction for latest carried kernel |
| Offline RPM transaction test | Signatures/keys and package file conflicts passed; zero application RPMs installed |
| Source checks | 35 focused tests; shell syntax/diff checks; actual media modes verified |

SHA-256:

```text
7c55e4f252661830ca917949bfda142ddbf7d4f5ade79235b4a09c3e1c1dc8e7
```

Copy the archive and its `.sha256` sidecar together. Read [the USB/local-repository quickstart](ON-SITE-QUICKSTART.md), [full installation procedure](INSTALL.md), and complete `SUPPORTED_KERNELS.txt` included in the artifact. The quickstart is inside the archive and can use local `file://` repositories without a new HTTP service. A machine-readable `BUILD-RECORD.json` accompanies the local transport. Binary payloads and that local receipt are intentionally excluded from source Git.

Package signatures and offline transaction tests establish preparation readiness. Target DKMS compilation, Secure Boot signing/trust where required, GPU initialization, actual card count/edition and application acceptance still need the site visit. The automatic offline test used the latest carried kernel; all 104 alternatives were not individually compiled or transaction-tested. Coverage is bounded by the complete signed stock pairs in the entitled repositories; it does not include every custom, historical or future kernel.

This verified artifact is published through the [GitHub release](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/tag/v2026.10.30-r580.196.07) as two byte parts with per-asset checksums and reassembly instructions. The reconstructed archive preserves the hash above. No production repository service or GPU target was changed by publication. Vendor RPMs retain their own licensing and entitlement terms and remain outside source Git history.


## Additive XZ transport — November 2, 2026

The original gzip record and acceptance above remain unchanged. The same release
adds `nvidia-r580-rhel8-driver-repo-20261030.tar.xz` (**2,024,025,344 bytes**, SHA-256 `f6b127cbd58f0265f6f91978aa61096844007c8b1a7e4eb94c8801fa01503db5`), its own checksum
sidecar, `XZ-TRANSPORT-RECORD.json` and `SINGLE-FILE-DOWNLOAD.md`. All original ten
assets are retained. The preferred XZ transport decodes to the original raw tar
stream: **4,628,807,680 bytes**, SHA-256 `b3214b0109f825276f7cd9b6f90c0df390d7f6aebdbaf6f0ef0603c2ed104bac`, equal to both the source
and independently decoded XZ length/SHA. This changes only outer compression;
all 617 RPMs, 104 exact development/header pairs, 654 checksums and original
metadata remain intact. See [the single-file guide](SINGLE-FILE-DOWNLOAD.md) and
[transport record](XZ-TRANSPORT-RECORD-20261102.json). No new GPU, DKMS or MATLAB
acceptance is implied; target facts remain unknown.
