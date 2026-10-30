# Security policy

## Payload and source separation

Keep RPM payloads, generated DNF repositories, tarballs, and ISOs outside Git
history. The local RHEL 8 port has no new published GitHub repository, release,
or binary artifact. Publish artifacts only through the organization's approved
process and under the vendors' applicable redistribution and entitlement terms.

Never include subscription certificates, entitlement private keys, CDN client
keys, repository credentials, tokens, passwords, SSH or module-signing private
keys, license files, internal repository URLs, private inventories, or host
logs in a public source or payload release. Public RPM signing keys are
verification material and are distinct from subscription client credentials.
Keep target evidence in the approved private change record.

## Integrity and trust controls

The builder pins NVIDIA's public-key fingerprint:

```text
610C7B14E068A878070DA4E99CD0A493D42D0685
```

It verifies NVIDIA RPM signatures in an isolated RPM database. It verifies
RHEL/EPEL RPM signatures against public Red Hat and EPEL 8 keys in another
isolated database. The importer repeats hash and RPM signature verification
before copying the payload. Clients keep `gpgcheck=1` for both repositories.
Never bypass a missing key, bad signature, or unexpected fingerprint.

Independently confirm the provenance of the Red Hat and EPEL keys before
building and before deploying them. A valid signature establishes which trusted
key signed an RPM; it does not establish target compatibility or dependency
closure. The revised builder includes a fresh empty-installroot driver/runtime
solve and classifies additional RPMs using isolated NVIDIA or Red Hat/EPEL
signature trust. Every final bundle must still pass an isolated transaction test
using only its paired repositories for the selected kernel and full package set.
Independent native paired-only resolution passed for the reviewed 617-RPM
union and latest carried kernel, producing a 410-package transaction with zero
RPMs installed. The final artifact must still contain its own successful
`OFFLINE_INSTALL_PREVIEW.txt` and pass final identity/signature/hash checks;
this intermediate solver proof is not a target installation or archive receipt.
A broad bundle lists package availability in `SUPPORTED_KERNELS.txt`; it does
not prove successful DKMS compilation or GPU operation on every listed kernel.

`SHA256SUMS` covers the transported bundle. Keep its approved digest or the
transport artifact's digest in an authenticated record outside the bundle.
Hashes detect changed content relative to that record; an attacker able to
replace a bundle and all its checksum files can replace both together.

The example repository file sets `repo_gpgcheck=0` because this workflow does
not sign regenerated repository metadata. RPM signature checks remain enabled.
Use the approved authenticated HTTPS repository service, trusted TLS
configuration, and verified transport. If metadata signing is required by site
policy, implement the approved signing and client-trust process before use.
Do not silently turn off verification or set `sslverify=0`.

## Target safeguards

- Build using available standard RHEL 8.10 pairs with `--all-kernels`, or a
  recorded explicit `--target-kernel`. Never infer a remote target from staging.
- On the client, require exact `kernel-devel` for the running kernel. Preserve
  installed compatible RHEL userspace `kernel-headers`; install the carried
  matching header only when headers are absent. Optional `--kernel` asserts an
  approved value; retain it for post-reboot validation.
- Use NVIDIA EL8 packages and the R580 open kernel-module stream. Match all
  driver-versioned kernel-module and userspace packages exactly. Independent
  support components such as EGL packages and the DNF plugin retain their own
  versions and must verify against the correct vendor key.
- Identify the official Open-DKMS package through its exact name/version/release,
  pinned vendor signature and upstream module membership, then validate the
  loaded open module after reboot. The EL8 umbrella RPM header `NVIDIA License`
  is not evidence of a proprietary kernel module.
- Use exact Red Hat target kernel development packages from entitled sources.
- Make DKMS installation explicit with `--dkms-fallback`; the compiler and
  build prerequisites change the target's package baseline.
- Restrict driver installation and prerequisite resolution to the two approved
  internal repositories. Prove offline dependency closure before acceptance.
- Retain the kernel versionlocks and use an approved kernel/driver patch cycle.
- Reuse only RPM files with `--rpm-cache` into a fresh output, rechecking all
  identities/signatures and regenerating metadata/manifests. Use `--resume` only
  for incomplete output. Never remove completion markers or copy old metadata
  to force a completed bundle through a different validation path.

For Secure Boot, use the site's approved signing process and a key trusted by
the host. These scripts do not disable Secure Boot, create a module-signing
private key, enroll a MOK, or establish a signing policy. A locally built module
must satisfy the target's existing Secure Boot policy before reboot acceptance.

## Reporting

Report security concerns privately to the repository owner through the
organization's established channel. Include a minimal sanitized reproduction.
Do not place secrets or internal environment evidence in public issues or
assume a GitHub security-reporting feature exists for this local project.
