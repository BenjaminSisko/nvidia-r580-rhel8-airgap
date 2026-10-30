# Download and verify the complete RHEL 8.10 offline kit

Get the complete binary kit from the [October 30 release](https://github.com/BenjaminSisko/nvidia-r580-rhel8-airgap/releases/tag/v2026.10.30-r580.196.07).
The GitHub source ZIP/TAR contains the source project. Download the release
assets for the full 617-RPM offline repository and its 104 kernel alternatives.

The original archive is 2,632,185,106 bytes. GitHub requires each release asset
to be under 2 GiB, so the archive is published as two ordered byte parts.
Concatenating them restores the exact previously tested archive. See
[GitHub's release asset limits](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).

Download **all release assets** into one new directory. With GitHub CLI:

```bash
gh release download v2026.10.30-r580.196.07 \
  --repo BenjaminSisko/nvidia-r580-rhel8-airgap \
  --dir nvidia-rhel8-download
cd nvidia-rhel8-download
bash reassemble-release.sh
```

The helper works on Linux and macOS. It verifies every downloaded asset,
joins `part-aa` followed by `part-ab`, verifies the original archive's pinned
SHA-256, and preserves an existing archive unless it already verifies.
The parts are **not separate tar archives** and should be concatenated first.

For manual reassembly on Linux:

```bash
sha256sum -c RELEASE-SHA256SUMS.txt
cat nvidia-r580-rhel8-driver-repo-20261030.tar.gz.part-aa \
    nvidia-r580-rhel8-driver-repo-20261030.tar.gz.part-ab \
  > nvidia-r580-rhel8-driver-repo-20261030.tar.gz
sha256sum -c nvidia-r580-rhel8-driver-repo-20261030.tar.gz.sha256
```

On macOS, use `shasum -a 256 -c` for the checksum commands.
The full archive's SHA-256 is:

```text
7c55e4f252661830ca917949bfda142ddbf7d4f5ade79235b4a09c3e1c1dc8e7
```

After verification:

```bash
tar -xzf nvidia-r580-rhel8-driver-repo-20261030.tar.gz
(cd repo-bundle && sha256sum -c SHA256SUMS)
```

On macOS, replace the last checksum command with `shasum -a 256 -c SHA256SUMS`.
All 654 per-file checksums should pass. The extracted file bytes total
4,628,279,520. Keep about 10 GB free while retaining both parts, the joined
archive and extracted repositories; the parts can be removed after the joined
archive has verified.

Read `repo-bundle/docs/ON-SITE-QUICKSTART.md` to use the two local repositories
on the RHEL 8.10 target. The release includes the full NVIDIA, RHEL/EPEL,
development and runtime dependencies; there is no CUDA Toolkit. No credentials,
subscription client certificates, private keys or private build-evidence
directory are included. Vendor RPMs retain their original licenses and terms.

The archive preserves the verified build snapshot. This release's build record
and download instructions supersede historical pre-publication status prose
inside that snapshot. The tested offline RPM transaction used the latest
carried kernel pair; target DKMS compilation, Secure Boot handling, GPU count
and application acceptance remain site checks.
