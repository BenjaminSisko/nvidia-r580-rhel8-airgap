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
closure. This port still needs an entitled full build and an isolated
paired-repository transaction test for the selected baseline and kernel scope.
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
- On the client, select the running kernel and refuse a missing exact development
  package pair before installation. Optional `--kernel` asserts an approved
  value; retain the installation value for post-reboot validation.
- Use NVIDIA EL8 packages and the R580 open kernel-module stream. Match all
  driver-versioned kernel-module and userspace packages exactly.
- Use exact Red Hat target kernel development packages from entitled sources.
- Make DKMS installation explicit with `--dkms-fallback`; the compiler and
  build prerequisites change the target's package baseline.
- Restrict driver installation and prerequisite resolution to the two approved
  internal repositories. Prove offline dependency closure before acceptance.
- Retain the kernel versionlocks and use an approved kernel/driver patch cycle.

For Secure Boot, use the site's approved signing process and a key trusted by
the host. These scripts do not disable Secure Boot, create a module-signing
private key, enroll a MOK, or establish a signing policy. A locally built module
must satisfy the target's existing Secure Boot policy before reboot acceptance.

## Reporting

Report security concerns privately to the repository owner through the
organization's established channel. Include a minimal sanitized reproduction.
Do not place secrets or internal environment evidence in public issues or
assume a GitHub security-reporting feature exists for this local project.
