"""The staged stream must contain the selected RPM artifacts, including older overrides."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PARSER = Path(__file__).resolve().parents[1] / "scripts" / "parse_sources.py"


class ModuleMembership(unittest.TestCase):
    def result(self, stream: str, version: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "modules.yaml").write_text(
                f"---\ndata:\n  stream: {stream}\n  artifacts:\n    rpms:\n"
                f"      - kmod-nvidia-open-dkms-3:{version}-1.el8.noarch\n")
            (root / "rpms.txt").write_text("kmod-nvidia-open-dkms-580.196.07-1.el8.noarch.rpm\n")
            return subprocess.run([sys.executable, str(PARSER), "verify-module-rpms", "--stream", "580-open",
                                   "--modules", str(root / "modules.yaml"), "--rpms-file", str(root / "rpms.txt")],
                                  capture_output=True, text=True)

    def test_epoch_is_normalized_for_filename_comparison(self) -> None:
        self.assertEqual(self.result("580-open", "580.196.07").returncode, 0)

    def test_wrong_stream_or_driver_artifacts_are_rejected(self) -> None:
        for stream, version in (("580", "580.196.07"), ("580-open", "580.178.04")):
            with self.subTest(stream=stream, version=version):
                result = self.result(stream, version)
                self.assertEqual(result.returncode, 42)
                self.assertIn("absent", result.stderr)
