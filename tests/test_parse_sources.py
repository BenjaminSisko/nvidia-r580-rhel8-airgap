#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PARSER = ROOT / "scripts" / "parse_sources.py"


STATUS = """<!doctype html><table>
<tr><th>Date</th><th>Component</th><th>Driver version</th><th>Kernel version</th><th>Kernel suffix</th></tr>
<tr><td>2026-09-24</td><td>kernel-core</td><td>-</td><td>4.18.0-553.125.1</td><td>el8_10.x86_64</td></tr>
<tr><td>2026-10-02</td><td>kernel-core</td><td>-</td><td>4.18.0-553.159.1</td><td>el8_10.x86_64</td></tr>
<tr><td>2026-10-01</td><td>kmod-nvidia</td><td>580.178.04</td><td>4.18.0-553.159.1</td><td>el8_10.x86_64</td></tr>
</table>"""


class ParserTests(unittest.TestCase):
    def run_coverage(self, index: str, require: bool = False) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "status.html").write_text(STATUS, encoding="utf-8")
            (root / "index.html").write_text(index, encoding="utf-8")
            command = [
                "python3",
                str(PARSER),
                "coverage",
                "--status-html",
                str(root / "status.html"),
                "--repo-index",
                str(root / "index.html"),
                "--as-of",
                "2026-10-05",
                "--days",
                "365",
            ]
            if require:
                command.append("--require-covered")
            return subprocess.run(command, text=True, capture_output=True, check=False)

    def test_target_kernel_is_gap_with_only_open_dkms(self) -> None:
        index = """<a href='kmod-nvidia-580.178.04-4.18.0-553.159.1-580.178.04-3.el8_10.x86_64.rpm'>p</a>
<a href='kmod-nvidia-open-dkms-580.178.04-1.el8.noarch.rpm'>d</a>"""
        result = self.run_coverage(index, require=True)
        self.assertEqual(result.returncode, 42)
        target = next(line for line in result.stdout.splitlines() if "553.125.1" in line)
        self.assertIn("\tGAP\t", target)
        self.assertIn("AVAILABLE_EXPLICIT_FLAG\t580.178.04", target)

    def test_proprietary_precompiled_package_is_never_open_coverage(self) -> None:
        index = """<a href='kmod-nvidia-580.178.04-4.18.0-553.159.1-580.178.04-3.el8_10.x86_64.rpm'>p</a>
<a href='kmod-nvidia-open-dkms-580.178.04-1.el8.noarch.rpm'>d</a>"""
        result = self.run_coverage(index)
        newer = next(line for line in result.stdout.splitlines() if "553.159.1" in line)
        self.assertIn("\tGAP\t", newer)
        self.assertIn("\t580.178.04\t", newer)

    def test_hypothetical_kernel_specific_open_rpm_is_covered(self) -> None:
        index = """<a href='kmod-nvidia-open-580.178.04-4.18.0-553.125.1-580.178.04-3.el8_10.x86_64.rpm'>o</a>"""
        result = self.run_coverage(index)
        target = next(line for line in result.stdout.splitlines() if "553.125.1" in line)
        self.assertIn("\tCOVERED\t580.178.04\t", target)

    def test_module_stream_listing_preserves_580_open(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            modules = Path(directory) / "modules.yaml"
            modules.write_text("data:\n  stream: 580-open\n---\ndata:\n  stream: 580\n", encoding="utf-8")
            result = subprocess.run(
                ["python3", str(PARSER), "module-streams", "--modules", str(modules)],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.splitlines(), ["580", "580-open"])

    def test_exact_open_dkms_version_is_available(self) -> None:
        index = "<a href='kmod-nvidia-open-dkms-580.178.04-1.el8.noarch.rpm'>d</a>"
        coverage = """release_date\tkernel\tstatus\topen_driver_version\topen_kmod_rpm\tstatus_page_proprietary_r580\tdkms_fallback\tdkms_driver_version\treason
2026-10-02\t4.18.0-553.125.1.el8_10.x86_64\tGAP\t\t\t580.178.04\tAVAILABLE_EXPLICIT_FLAG\t580.178.04\tgap
"""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "index.html").write_text(index, encoding="utf-8")
            (root / "coverage.tsv").write_text(coverage, encoding="utf-8")
            result = subprocess.run(
                [
                    "python3",
                    str(PARSER),
                    "dkms-fallbacks",
                    "--repo-index",
                    str(root / "index.html"),
                    "--coverage",
                    str(root / "coverage.tsv"),
                    "--require-all",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("580.178.04\tAVAILABLE", result.stdout)


class El8SelectionTests(unittest.TestCase):
    run_coverage = ParserTests.run_coverage
    def test_other_major_release_is_never_coverage(self) -> None:
        index = "<a href='kmod-nvidia-open-580.178.04-4.18.0-553.125.1-580.178.04-3.el9_8.x86_64.rpm'>wrong</a>"
        result = self.run_coverage(index, require=True)
        self.assertEqual(result.returncode, 42)

    def test_similar_kernel_prefix_is_not_an_exact_match(self) -> None:
        index = "<a href='kmod-nvidia-open-580.178.04-4.18.0-553.125.10-580.178.04-3.el8_10.x86_64.rpm'>wrong</a>"
        result = self.run_coverage(index, require=True)
        self.assertEqual(result.returncode, 42)

    def test_pinned_dkms_is_independent_of_status_history(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            index = Path(directory) / "index.html"
            index.write_text("<a href='kmod-nvidia-open-dkms-580.196.07-1.el8.noarch.rpm'>yes</a>"
                             "<a href='kmod-nvidia-open-dkms-580.196.07-1.el9.noarch.rpm'>wrong</a>")
            result = subprocess.run(["python3", str(PARSER), "dkms-fallbacks", "--repo-index", str(index),
                                     "--driver-version", "580.196.07", "--require-all"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("580.196.07\tAVAILABLE\t", result.stdout)
            self.assertNotIn("el9", result.stdout)

    def test_only_el9_dkms_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            index = Path(directory) / "index.html"
            index.write_text("<a href='kmod-nvidia-open-dkms-580.196.07-1.el9.noarch.rpm'>wrong</a>")
            result = subprocess.run(["python3", str(PARSER), "dkms-fallbacks", "--repo-index", str(index),
                                     "--driver-version", "580.196.07", "--require-all"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 42)
            self.assertIn("MISSING", result.stdout)


if __name__ == "__main__":
    unittest.main()
