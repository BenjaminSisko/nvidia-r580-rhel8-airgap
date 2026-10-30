"""Exercise runtime guards with controlled command stubs; no host changes."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMMON = ROOT / "scripts" / "rhel8-common.sh"
KERNEL = "4.18.0-553.125.1.el8_10.x86_64"
DRIVER = "580.196.07"


class ShellGuards(unittest.TestCase):
    def run_shell(self, code: str, **values: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(["bash", "-c", 'set -Eeuo pipefail; . "$COMMON"; ' + code],
                              text=True, capture_output=True,
                              env={**os.environ, "COMMON": str(COMMON), **values})

    def test_baseline_and_updated_stock_kernels_are_accepted(self) -> None:
        for kernel in ("4.18.0-553.el8_10.x86_64", KERNEL):
            with self.subTest(kernel=kernel):
                self.assertEqual(self.run_shell('valid_target_kernel "$TARGET"', TARGET=kernel).returncode, 0)

    def test_wrong_release_architecture_or_custom_kernel_is_rejected(self) -> None:
        for kernel in ("5.14.0-687.51.1.el9_8.x86_64", "4.18.0-553.125.1.el8_9.x86_64",
                       "4.18.0-553.125.1.el8_10.aarch64", "4.18.0-553.125.el8_10.x86_64",
                       "4.18.0-553.125.1.el8_10.x86_64.debug"):
            with self.subTest(kernel=kernel):
                self.assertNotEqual(self.run_shell('valid_target_kernel "$TARGET"', TARGET=kernel).returncode, 0)

    RPM_STUB = '''rpm() {
        case "$*" in
          *--provides*) printf 'kmod(nvidia.ko)\\nkernel-modules = %s\\n' "$TARGET" ;;
          *--conflicts*) printf '' ;;
          *'%{RELEASE}|%{ARCH}'*) printf '%s|%s\\n' "$RELEASE" "$ARCH" ;;
          *) printf '%s|%s|%s\\n' "$NAME" "$VERSION" "$LICENSE" ;;
        esac
    }; '''

    def header_result(self, function: str = "verify_open_dkms", **overrides: str) -> subprocess.CompletedProcess[str]:
        values = dict(NAME="kmod-nvidia-open-dkms", VERSION=DRIVER, LICENSE="Dual MIT/GPL",
                      RELEASE="1.el8", ARCH="noarch", TARGET=KERNEL)
        values.update(overrides)
        args = 'sample.rpm "$TARGET" ' if function == "verify_open_kmod" else "sample.rpm "
        # Conditional context reproduces the inherited errexit bug.
        return self.run_shell(self.RPM_STUB + f'if {function} {args}{DRIVER}; then exit 0; else exit 1; fi', **values)

    def test_valid_open_dkms_header(self) -> None:
        self.assertEqual(self.header_result().returncode, 0)

    def test_header_rejects_each_early_mismatch_even_in_conditional_context(self) -> None:
        for bad in (dict(NAME="kmod-nvidia-latest-dkms"), dict(VERSION="580.178.04"),
                    dict(LICENSE="Nvidia"), dict(RELEASE="1.el9"), dict(ARCH="aarch64")):
            with self.subTest(bad=bad):
                self.assertNotEqual(self.header_result(**bad).returncode, 0)

    def test_el8_appstream_modular_and_standard_release_tags_are_accepted(self) -> None:
        for release in ("422.module+el8.10.0+21673+5ce1591e", "1.module+el8.6.0+14238+f4e0b588",
                        "1.el8", "1.el8_10", "1.el8_10.1"):
            with self.subTest(release=release):
                self.assertEqual(self.header_result(RELEASE=release).returncode, 0)

    def test_el9_modular_and_mixed_release_tags_are_rejected(self) -> None:
        for release in ("422.module+el9.6.0+21673+5ce1591e", "1.el9.el8", "1.el8.el9",
                        "1.el9.module+el8.10.0+21673+hash", "1.module+el8.10.0+el9.0+hash"):
            with self.subTest(release=release):
                self.assertNotEqual(self.header_result(RELEASE=release).returncode, 0)

    def test_precompiled_open_rejects_proprietary_name(self) -> None:
        result = self.header_result("verify_open_kmod", NAME="kmod-nvidia", ARCH="x86_64")
        self.assertNotEqual(result.returncode, 0)

    def test_valid_precompiled_open_header(self) -> None:
        result = self.header_result("verify_open_kmod", NAME="kmod-nvidia-open", ARCH="x86_64")
        self.assertEqual(result.returncode, 0, result.stderr)

    def gpu_result(self, **overrides: str) -> subprocess.CompletedProcess[str]:
        values = dict(RUNNING_KERNEL=KERNEL, GPU_VERSIONS=DRIVER + "\n" + DRIVER,
                      GPU_INDEXES="0\n1", MODULE_TEXT="NVRM version: NVIDIA UNIX Open Kernel Module")
        values.update(overrides)
        with tempfile.TemporaryDirectory() as directory:
            version = Path(directory) / "nvidia-version"
            version.write_text(values.pop("MODULE_TEXT"))
            stub = '''uname() { printf '%s\\n' "$RUNNING_KERNEL"; };
            nvidia-smi() {
                case "${1:-}" in
                    --query-gpu=driver_version) printf '%s\\n' "$GPU_VERSIONS" ;;
                    --query-gpu=index) printf '%s\\n' "$GPU_INDEXES" ;;
                    *) printf 'GPU summary\\n' ;;
                esac
            }; '''
            return self.run_shell(stub + 'validate_gpu_state "$TARGET" "$DRIVER" 2 "$VERSION_FILE"',
                                  **values, TARGET=KERNEL, DRIVER=DRIVER, VERSION_FILE=str(version))

    def test_valid_gpu_state(self) -> None:
        result = self.gpu_result()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_gpu_validation_rejects_kernel_version_count_and_proprietary_module(self) -> None:
        for bad in (dict(RUNNING_KERNEL="wrong"), dict(GPU_VERSIONS=DRIVER + "\n580.178.04"),
                    dict(GPU_INDEXES="0"), dict(MODULE_TEXT="NVIDIA UNIX x86_64 Kernel Module")):
            with self.subTest(bad=bad):
                self.assertNotEqual(self.gpu_result(**bad).returncode, 0)

    def test_build_requires_selection_and_client_rejects_wrong_explicit_kernel(self) -> None:
        for script, arguments in (("build-driver-repo.sh", ["--dry-run"]), ("client-install.sh", ["--kernel", "5.14.0-687.51.1.el9_8.x86_64"])):
            result = subprocess.run(["bash", str(ROOT / "scripts" / script), *arguments],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("required" if script.startswith("build") else "stock RHEL 8.10", result.stderr)


class BuilderReplay(unittest.TestCase):
    """Run real builder control flow with only host/network/DNF prerequisites stubbed."""

    def run_builder(self, options: list[str], missing: str = "") -> tuple[subprocess.CompletedProcess[str], str]:
        import shutil
        import sys
        userspace = ("libnvidia-cfg libnvidia-fbc libnvidia-gpucomp libnvidia-ml nvidia-driver "
                     "nvidia-driver-cuda nvidia-driver-cuda-libs nvidia-driver-libs nvidia-kmod-common "
                     "nvidia-libXNVCtrl nvidia-libXNVCtrl-devel nvidia-modprobe nvidia-persistenced "
                     "nvidia-settings nvidia-xconfig xorg-x11-nvidia").split()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "scripts"
            scripts.mkdir()
            for name in ("build-driver-repo.sh", "parse_sources.py", "rhel8-common.sh"):
                shutil.copy2(ROOT / "scripts" / name, scripts / name)
            # The tests never change /etc/os-release. Only this copied prerequisite is mocked.
            with (scripts / "rhel8-common.sh").open("a") as handle:
                handle.write("\nrequire_rhel810_host() { :; }\n")
            files = [f"{name}-{DRIVER}-1.el8.{'noarch' if name == 'nvidia-kmod-common' else 'x86_64'}.rpm"
                     for name in userspace]
            files += [f"kmod-nvidia-open-dkms-{DRIVER}-1.el8.noarch.rpm", "dnf-plugin-nvidia-2.3-1.el8.noarch.rpm",
                      "dnf-plugin-nvidia-99.0-1.el9.noarch.rpm"]
            (root / "index.html").write_text("\n".join(f"<a href='{item}'>rpm</a>" for item in files))
            (root / "status.html").write_text("<table></table>")
            artifacts = [item[:-4].replace("-" + DRIVER, "-3:" + DRIVER) for item in files if DRIVER in item]
            (root / "modules.yaml").write_text("data:\n  stream: 580-open\n  artifacts:\n    rpms:\n" +
                                                "".join("      - " + item + "\n" for item in artifacts))
            commands = root / "bin"
            commands.mkdir()
            stubs = {
                "curl": '#!/bin/bash\nwhile (($#)); do if [[ "$1" == -o ]]; then printf key > "$2"; exit; fi; shift; done\nexit 1\n',
                "gpg": '#!/bin/bash\nprintf "fpr:::::::::610C7B14E068A878070DA4E99CD0A493D42D0685:\\n"\n',
                "dnf": '''#!/bin/bash
printf '%s\\n' "$*" >> "$MOCK_DNF_LOG"
case "$*" in
  *'%{nevra}'*) printf "unsupported RHEL 8 DNF query field\\n" >&2; exit 7 ;;
  *--showduplicates*kernel-devel*) printf '4.18.0-553.el8_10.x86_64\\n4.18.0-553.125.1.el8_10.x86_64\\n4.18.0-553.125.1.el8_10.x86_64\\n5.14.0-687.51.1.el9_8.x86_64\\n' ;;
  *) if [[ -n "$MISSING_SPEC" && "$*" == *"$MISSING_SPEC"* ]]; then exit 0; fi; printf available ;;
esac
''',
            }
            for name, body in stubs.items():
                path = commands / name
                path.write_text(body)
                path.chmod(0o755)
            log = root / "dnf.log"
            result = subprocess.run(["bash", str(scripts / "build-driver-repo.sh"), *options,
                                     "--status-html", str(root / "status.html"),
                                     "--repo-index", str(root / "index.html"),
                                     "--modules-yaml", str(root / "modules.yaml")],
                                    capture_output=True, text=True,
                                    env={**os.environ, "PATH": str(commands) + os.pathsep + os.environ["PATH"],
                                         "PYTHON_BIN": sys.executable, "MOCK_DNF_LOG": str(log), "MISSING_SPEC": missing})
            return result, log.read_text() if log.exists() else ""

    def test_metadata_only_needs_neither_kernel_nor_dnf(self) -> None:
        result, calls = self.run_builder(["--metadata-only"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls, "")
        self.assertIn(f"kmod-nvidia-open-dkms-{DRIVER}-1.el8.noarch.rpm", result.stdout)
        self.assertNotIn("99.0-1.el9", result.stdout)

    def test_all_kernels_selects_and_checks_every_exact_pair(self) -> None:
        result, calls = self.run_builder(["--all-kernels", "--dry-run"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Selected 2 stock RHEL 8.10 kernels", result.stdout)
        self.assertIn("kernel-devel-4.18.0-553.el8_10.x86_64", calls)
        self.assertIn("kernel-headers-" + KERNEL, calls)
        self.assertNotIn("kernel-headers-5.14", calls)

    def test_missing_header_blocks_multi_kernel_dry_run(self) -> None:
        result, _ = self.run_builder(["--all-kernels", "--dry-run"], missing="kernel-headers-" + KERNEL)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertIn("required RHEL/EPEL package is unavailable", result.stdout)


if __name__ == "__main__":
    unittest.main()
