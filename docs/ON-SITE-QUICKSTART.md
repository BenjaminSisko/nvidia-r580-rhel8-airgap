# On-site quickstart: use the verified bundle locally on RHEL 8.10

This optional path installs from an extracted USB/media bundle through
`file://` DNF repositories. It needs no new HTTP server, DNS record, firewall
rule or network publication. These are **operator instructions**; no target
commands were run while preparing this document. The final archive's recorded
hash and its included `OFFLINE_INSTALL_PREVIEW.txt` remain the artifact
acceptance sources. Actual GPU, DKMS and Secure Boot acceptance happen here.

Use RHEL 8.10 x86_64 with Bash, DNF/RPM, GnuPG and `lspci` available. Read the
bundle's `docs/INSTALL.md` and follow the site's existing handling/signing
process. Confirm the physical GPU edition/count; the earlier six-GPU default
is not evidence about this box.

## 1. Verify media and extract to a stable local path

Use the actual archive filename on the approved mounted media:

```bash
ARCHIVE='/path/to/media/ACTUAL_BUNDLE.tar.gz'
(cd "$(dirname -- "$ARCHIVE")" && \
  sha256sum -c "$(basename -- "$ARCHIVE").sha256")
```

Compare the archive SHA-256 with the approved value retained separately from
the media. Stop on any mismatch. Preserve any existing
`/opt/nvidia-rhel8/repo-bundle`; use a fresh reviewed destination rather than
overlaying it. For a new destination:

```bash
sudo install -d -m 0755 /opt/nvidia-rhel8
sudo tar -xzf "$ARCHIVE" -C /opt/nvidia-rhel8
BUNDLE=/opt/nvidia-rhel8/repo-bundle
(cd "$BUNDLE" && sha256sum -c SHA256SUMS)
```

If the media already contains an extracted `repo-bundle/`, copy that complete
directory to `/opt/nvidia-rhel8/` instead of extracting a tarball, then run the
same `SHA256SUMS` check. Keep its `drivers/`, `os-deps/`, keys, metadata,
`client-install.sh` and `rhel8-common.sh` together. Keep this stable local copy
while these repositories are enabled; removing the USB must not break them.

Check the pinned NVIDIA public-key fingerprint without importing a private key:

```bash
NVIDIA_FPR="$(gpg --show-keys --with-colons --fingerprint \
  "$BUNDLE/NVIDIA-GPG-KEY-D42D0685.pub" 2>/dev/null | \
  awk -F: '$1=="fpr" {print toupper($10); exit}')"
printf '%s\n' "$NVIDIA_FPR"
test "$NVIDIA_FPR" = '610C7B14E068A878070DA4E99CD0A493D42D0685'
```

Stop unless it matches exactly. Verify the Red Hat/EPEL public-key provenance
through the approved vendor/site source too. These are public RPM signing keys,
not Red Hat entitlement certificates or private client keys. No entitlement
material belongs on this target or media.

## 2. Define the two local repositories

Keep one definition per ID. If these IDs already exist in another repository
file, reconcile that definition through the site's normal repository workflow
before adding this local file.

```bash
sudo tee /etc/yum.repos.d/nvidia-r580-rhel8-local.repo >/dev/null <<'REPO'
[nvidia-r580-rhel8-internal]
name=Local NVIDIA R580 EL8 driver and runtime support
baseurl=file:///opt/nvidia-rhel8/repo-bundle/drivers/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=file:///opt/nvidia-rhel8/repo-bundle/NVIDIA-GPG-KEY-D42D0685.pub

[nvidia-r580-rhel8-os-deps]
name=Local RHEL8 kernel, toolchain and driver runtime dependencies
baseurl=file:///opt/nvidia-rhel8/repo-bundle/os-deps/
enabled=1
gpgcheck=1
repo_gpgcheck=0
module_hotfixes=1
gpgkey=file:///opt/nvidia-rhel8/repo-bundle/keys/RPM-GPG-KEY-redhat-release file:///opt/nvidia-rhel8/repo-bundle/keys/RPM-GPG-KEY-EPEL-8
REPO

sudo dnf --disablerepo='*' \
  --enablerepo=nvidia-r580-rhel8-internal \
  --enablerepo=nvidia-r580-rhel8-os-deps repolist
```

`gpgcheck=1` verifies RPM signatures. Repository metadata is regenerated and
unsigned (`repo_gpgcheck=0`), so the independently approved archive digest and
verified local copy matter. `module_hotfixes=1` is scoped to the verified OS
repository for its carried AppStream modular runtime RPMs. No external OS
repository should be needed for the accepted full transaction.

## 3. Capture the target and confirm kernel coverage

```bash
cat /etc/redhat-release
uname -m
TARGET_KERNEL="$(uname -r)"
lspci -Dnn -d 10de:
EXPECTED_GPUS="$(lspci -Dn -d 10de: | \
  awk '$2=="0300:" || $2=="0302:" {n++} END {print n+0}')"
printf 'Kernel: %s\nNVIDIA VGA/3D PCI devices: %s\n' \
  "$TARGET_KERNEL" "$EXPECTED_GPUS"
test "$EXPECTED_GPUS" -gt 0

sudo dnf --disablerepo='*' --enablerepo=nvidia-r580-rhel8-os-deps \
  repoquery --available "kernel-devel-${TARGET_KERNEL}"
rpm -q kernel-headers
mokutil --sb-state
```

The count filters NVIDIA VGA/3D functions instead of counting audio or other
NVIDIA devices. Confirm it against the physical inventory; a missing card can
also be absent from PCI enumeration. Confirm the release/architecture and
compare the running kernel with `SUPPORTED_KERNELS.txt`. Stop if exact
`kernel-devel` is absent. Preserve installed compatible RHEL userspace
`kernel-headers`; its version need not equal `uname -r`. When headers are
absent, the installer uses the carried matching header.

Record the confirmed pre-install expectation so a changed reboot cannot become
its own expected value:

```bash
printf 'TARGET_KERNEL=%q\nEXPECTED_GPUS=%q\n' \
  "$TARGET_KERNEL" "$EXPECTED_GPUS" | \
  sudo tee /opt/nvidia-rhel8/target-expectations.env >/dev/null
```

If Secure Boot is enabled, establish the approved DKMS module-signing/trusted-key
path. This kit does not disable Secure Boot, create private signing keys or
enroll a MOK. Existing execution controls also remain in force.

## 4. Install, check the build, then reboot in the approved window

```bash
cd /opt/nvidia-rhel8/repo-bundle
sudo ./client-install.sh --kernel "$TARGET_KERNEL" \
  --driver-version 580.196.07 --expected-gpus "$EXPECTED_GPUS" \
  --dkms-fallback --no-reboot

dkms status
modinfo -k "$TARGET_KERNEL" -F version nvidia
modinfo -k "$TARGET_KERNEL" -F signer nvidia
dnf versionlock list
```

Review exact-kernel DKMS success and, where required, the approved module
signer before rebooting. The explicit fallback installs the build toolchain,
including GCC/G++, Python 3.6 package prerequisites and DKMS. It does not install
the CUDA Toolkit or another kernel image. Use the site's approved reboot and
rollback process; retain the previous bootable OS kernel and transaction log.

## 5. Validate after reboot against the recorded expectation

```bash
source /opt/nvidia-rhel8/target-expectations.env
cd /opt/nvidia-rhel8/repo-bundle
sudo ./client-install.sh --validate --kernel "$TARGET_KERNEL" \
  --driver-version 580.196.07 --expected-gpus "$EXPECTED_GPUS"

nvidia-smi --query-gpu=index,name,driver_version,pci.bus_id --format=csv
systemctl is-active nvidia-persistenced
journalctl -b -k | grep -Ei 'nvidia|nvrm|xid|lockdown|verification'
```

Require the recorded kernel/count, correct GPU edition and driver, loaded open
modules, persistence health, versionlocks and no unresolved signing/NVRM/XID
failure. Validate the actual application separately. Do not redefine the
expected GPU count from post-reboot `nvidia-smi`, because that could hide a
missing GPU. Preserve the evidence and use `docs/INSTALL.md` or
`docs/LLM-CONTEXT.md` for diagnosis.
