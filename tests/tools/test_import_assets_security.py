"""Security regressions for batch metadata; no deliveries or reports touch the repository."""
import contextlib
import importlib.util
import io
import json
import pathlib
import sys
import tempfile
import types
import unittest
import zipfile
from unittest import mock

# Image-only checks do not need the optional audio dependency.
try:
    import soundfile  # noqa: F401
except ImportError:
    sys.modules["soundfile"] = types.ModuleType("soundfile")

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("starfire_asset_intake", ROOT / "tools/import_assets.py")
intake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(intake)


class AssetIntakeBoundaryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="starfire-intake-test-")
        self.root = pathlib.Path(self.temp.name)
        self.reports = self.root / "intended" / "reports" / "assets"
        self.reports_patch = mock.patch.object(intake, "REPORTS", self.reports)
        self.reports_patch.start()
        self.addCleanup(self.reports_patch.stop)
        self.addCleanup(self.temp.cleanup)

    def archive(self, batch=1, kind="vignette"):
        path = self.root / "batch.zip"
        manifest = {"kind": kind, "batch": batch, "licence": "CC0", "source": "test",
                    "items": [{"id": "test_asset", "file": "test_asset.png"}]}
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("manifest.json", json.dumps(manifest))
            archive.writestr("test_asset.png", b"not decoded by the test handler")
        return path

    @staticmethod
    def handler(item, files, archive, notes):
        from PIL import Image
        item.thumb = Image.new("RGBA", (8, 8), (20, 30, 40, 255))
        item.outputs = [("vignette/test_asset.webp", b"output", None)]

    def test_path_batch_is_rejected_as_failure_before_any_write(self):
        path = self.archive(batch="../../../../escaped")
        with mock.patch.dict(intake.HANDLERS, {"vignette": self.handler}), contextlib.redirect_stdout(io.StringIO()):
            items = intake.ingest(path, types.SimpleNamespace(check=True, replace=False),
                                  {"test_asset": {"kind": "vignette", "status": "placeholder"}}, "2026-11-14")
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].verdict, "FAIL")
        self.assertEqual([p for p in self.root.rglob("*") if p.is_file()], [path])

    def test_check_mode_writes_neither_outputs_nor_reports(self):
        path = self.archive()
        with mock.patch.dict(intake.HANDLERS, {"vignette": self.handler}), contextlib.redirect_stdout(io.StringIO()):
            items = intake.ingest(path, types.SimpleNamespace(check=True, replace=False),
                                  {"test_asset": {"kind": "vignette", "status": "placeholder"}}, "2026-11-14")
        self.assertEqual(items[0].verdict, "PASS")
        self.assertEqual([p for p in self.root.rglob("*") if p.is_file()], [path])
        self.assertFalse(self.reports.exists())

    def test_invalid_batch_produces_nonzero_cli_exit(self):
        path = self.archive(batch="../../escape")
        argv = ["import_assets.py", "--zip", str(path), "--check"]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(intake, "load_manifest", return_value={"assets": []}), \
             mock.patch.object(intake, "budget_report", return_value=True), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                intake.main()
        self.assertEqual(result.exception.code, 1)
        self.assertFalse(self.reports.exists())

    def test_oversized_manifest_is_rejected_before_decode(self):
        path = self.root / "batch.zip"
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("manifest.json", b" " * (intake.MAX_MANIFEST_BYTES + 1))
        with contextlib.redirect_stdout(io.StringIO()):
            result = intake.ingest(path, types.SimpleNamespace(check=True), {}, "test")
        self.assertEqual(result[0].verdict, "FAIL")
        self.assertIn("size limit", result[0].fails[0])
        self.assertFalse(self.reports.exists())

    def test_oversized_asset_is_rejected_before_handler(self):
        path = self.archive()
        getinfo = zipfile.ZipFile.getinfo

        def advertised_size(archive, name):
            info = getinfo(archive, name)
            if name == "test_asset.png":
                info.file_size = intake.MAX_ASSET_BYTES + 1
            return info

        handler = mock.Mock(side_effect=self.handler)
        with mock.patch.object(zipfile.ZipFile, "getinfo", advertised_size), \
             mock.patch.dict(intake.HANDLERS, {"vignette": handler}), contextlib.redirect_stdout(io.StringIO()):
            items = intake.ingest(path, types.SimpleNamespace(check=False, replace=False),
                                  {"test_asset": {"kind": "vignette", "status": "placeholder"}}, "2026-11-14")
        self.assertEqual(items[0].verdict, "FAIL")
        handler.assert_not_called()
        self.assertFalse(self.reports.exists())

    def test_empty_delivery_cannot_succeed(self):
        path = self.root / "empty.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("manifest.json", json.dumps({"kind": "vignette", "batch": 1,
                                                         "licence": "CC0", "source": "test", "items": []}))
        with contextlib.redirect_stdout(io.StringIO()):
            result = intake.ingest(path, types.SimpleNamespace(check=True), {}, "test")
        self.assertEqual(result[0].verdict, "FAIL")

    def test_bad_archive_and_non_object_manifest_are_failures(self):
        invalid = self.root / "invalid.zip"
        invalid.write_bytes(b"not a zip")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(intake.ingest(invalid, types.SimpleNamespace(check=True), {}, "test")[0].verdict, "FAIL")
        with zipfile.ZipFile(invalid, "w") as archive:
            archive.writestr("manifest.json", "[]")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(intake.ingest(invalid, types.SimpleNamespace(check=True), {}, "test")[0].verdict, "FAIL")


if __name__ == "__main__":
    unittest.main()
