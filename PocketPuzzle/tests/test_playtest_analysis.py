import importlib.util
import json
import pathlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("analysis", pathlib.Path("tools/analyze_playtests.py"))
analysis = importlib.util.module_from_spec(spec)
spec.loader.exec_module(analysis)

class ReviewTests(unittest.TestCase):
    def test_review_and_dedup_without_personal_notes(self):
        with tempfile.TemporaryDirectory() as folder:
            paths = []
            for index in range(3):
                path = pathlib.Path(folder) / f"report-{index}.json"
                path.write_text(json.dumps({"format": "PocketPuzzlePlaytest", "version": 1, "entries": [{"mode": "parcel", "level": 0, "seed": 7, "rating": "hard", "note": f"private {index}", "difficulty_estimate": "Gentle"}]}))
                paths.append(path)
            rows, skipped = analysis.analyze(paths + [paths[0]], {"parcel": [{"seed": 7}]})
            self.assertEqual((len(rows), rows[0]["source_files"], skipped), (1, 3, 0))
            self.assertIn("reference goal", rows[0]["review"])
            self.assertNotIn("private", json.dumps(rows))

    def test_private_admin_escapes_notes_and_marks_empty_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            report = pathlib.Path(folder) / "report.json"
            report.write_text(json.dumps({"format": "PocketPuzzlePlaytest", "version": 1, "entries": [{"note": "<script>alert(1)</script>", "mode": "parcel", "level": 0}]}))
            destination = pathlib.Path(folder) / "admin.html"
            analysis.write_admin(destination, [], 0, [report])
            page = destination.read_text()
            self.assertNotIn("<script>", page)
            self.assertIn("&lt;script&gt;", page)
            self.assertIn("No real-player evidence loaded", page)
            self.assertIn("default-src 'none'", page)

    def test_stale_and_unrecognized_reports_are_skipped(self):
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / "report.json"
            path.write_text(json.dumps({"format": "PocketPuzzlePlaytest", "version": 1, "entries": [{"mode": "parcel", "level": 0, "seed": -1, "rating": "hard"}]}))
            self.assertEqual(analysis.analyze([path], {"parcel": [{"seed": 7}]}), ([], 1))

if __name__ == "__main__":
    unittest.main()
