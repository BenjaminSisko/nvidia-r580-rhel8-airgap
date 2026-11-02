import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "stage-matlab-addons.py"
SPEC = importlib.util.spec_from_file_location("matlab_stager", SCRIPT)
stager = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stager)


class Response(io.BytesIO):
    def __init__(self, content, url, declared_size=None):
        super().__init__(content)
        self.url = url
        self.headers = {"Content-Length": str(len(content) if declared_size is None else declared_size)}

    def geturl(self):
        return self.url


class StagerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name).resolve()
        self.content = b"pinned vendor bytes\n"
        self.asset = {
            "component": "example", "version": "1", "filename": "example.tar.xz",
            "url": "https://developer.download.nvidia.com/example.tar.xz",
            "size_bytes": len(self.content),
            "sha256": hashlib.sha256(self.content).hexdigest(), "profile": "cuda-test",
        }
        self.manifest = self.directory / "manifest.json"

    def save_manifest(self, assets=None):
        self.manifest.write_text(json.dumps({"schema_version": 1, "assets": assets or [self.asset]}))

    def test_manifest_rejects_path_traversal_or_duplicate_names(self):
        bad = dict(self.asset, filename="../example.tar.xz")
        self.save_manifest([bad])
        with self.assertRaises(ValueError):
            stager.load_manifest(self.manifest)
        self.save_manifest([self.asset, self.asset])
        with self.assertRaises(ValueError):
            stager.load_manifest(self.manifest)

    def test_manifest_rejects_untrusted_or_non_https_downloads(self):
        for url in ("http://developer.download.nvidia.com/example.tar.xz",
                    "https://untrusted.invalid/example.tar.xz",
                    "https://developer.download.nvidia.com/example.tar.xz?token=value"):
            self.save_manifest([dict(self.asset, url=url)])
            with self.assertRaises(ValueError):
                stager.load_manifest(self.manifest)

    def test_verified_existing_payload_is_reused_without_network(self):
        target = self.directory / self.asset["filename"]
        target.write_bytes(self.content)
        with patch.object(stager.urllib.request, "urlopen") as network:
            stager.fetch_asset(self.asset, self.directory)
            network.assert_not_called()

    def test_changed_existing_payload_is_preserved_and_refused(self):
        target = self.directory / self.asset["filename"]
        target.write_bytes(b"different")
        with self.assertRaises(ValueError):
            stager.fetch_asset(self.asset, self.directory)
        self.assertEqual(target.read_bytes(), b"different")

    def test_corrupt_download_never_gets_final_filename(self):
        response = Response(b"x" * len(self.content), self.asset["url"])
        with patch.object(stager.urllib.request, "urlopen", return_value=response):
            with self.assertRaises(ValueError):
                stager.fetch_asset(self.asset, self.directory)
        self.assertFalse((self.directory / self.asset["filename"]).exists())
        self.assertTrue((self.directory / (self.asset["filename"] + ".part")).exists())

    def test_redirect_to_unapproved_host_is_refused(self):
        response = Response(self.content, "https://untrusted.invalid/example.tar.xz")
        with patch.object(stager.urllib.request, "urlopen", return_value=response):
            with self.assertRaises(ValueError):
                stager.fetch_asset(self.asset, self.directory)

    def test_symlink_asset_cannot_be_read_or_overwritten(self):
        original = self.directory / "original"
        original.write_bytes(self.content)
        target = self.directory / self.asset["filename"]
        target.symlink_to(original)
        with self.assertRaises(ValueError):
            stager.fetch_asset(self.asset, self.directory)
        self.assertEqual(original.read_bytes(), self.content)

    def test_disk_reserve_blocks_download_before_network(self):
        self.save_manifest()
        output = self.directory / "stage"
        usage = type("Usage", (), {"free": stager.RESERVE_BYTES})()
        with patch.object(stager.shutil, "disk_usage", return_value=usage):
            with patch.object(stager.urllib.request, "urlopen") as network:
                with self.assertRaises(ValueError):
                    stager.run(["--manifest", str(self.manifest), "--output", str(output), "--fetch"])
                network.assert_not_called()

    def test_successful_download_and_offline_verify_receipt(self):
        self.save_manifest()
        output = self.directory / "stage"
        response = Response(self.content, self.asset["url"])
        with patch.object(stager.urllib.request, "urlopen", return_value=response):
            stager.run(["--manifest", str(self.manifest), "--output", str(output), "--fetch"])
        with patch.object(stager.urllib.request, "urlopen") as network:
            stager.run(["--manifest", str(self.manifest), "--output", str(output), "--verify"])
            network.assert_not_called()
        receipt = json.loads((output / "FETCH-RECEIPT.json").read_text())
        self.assertEqual(receipt["operation"], "offline_verify")
        self.assertFalse(receipt["installed_on_target"])
        self.assertEqual((output / "payload" / self.asset["filename"]).read_bytes(), self.content)


if __name__ == "__main__":
    unittest.main()
