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

This is a local artifact. No new public GitHub release or production repository publication was performed. Vendor RPMs retain their own licensing and entitlement terms and remain outside source Git.
