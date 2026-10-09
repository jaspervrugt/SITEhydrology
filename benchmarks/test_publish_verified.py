import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from publish_verified import publish
import test_validate_submission as validation_fixture


class PublicationTests(unittest.TestCase):
    def setUp(self):
        fixture = validation_fixture.ValidationTests()
        fixture.setUp()
        self.payload, self.manifest = fixture.payload, fixture.manifest
        self.payload["contract"]["maximize"] = [True]
        self.manifest["profiles"][0]["contract"]["maximize"] = [True]
        self.tmp = tempfile.TemporaryDirectory(dir=Path(__file__).parent,
                                               ignore_cleanup_errors=True)
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.candidate = self.root / "candidate.json"
        self.profiles = self.root / "profiles.json"
        self.receipt = self.root / "receipt.json"
        self.publication = self.root / "published"
        self.profiles.write_text(json.dumps(self.manifest))

    def submit(self):
        self.candidate.write_text(json.dumps(self.payload))
        receipt = {"scores_verified": True, "profile": "test", "checked": 1,
                   "candidate_sha256": hashlib.sha256(self.candidate.read_bytes()).hexdigest(),
                   "manifest_sha256": hashlib.sha256(self.profiles.read_bytes()).hexdigest(),
                   "verifier_revision": "trusted-test", "verified_records": self.payload["records"]}
        self.receipt.write_text(json.dumps(receipt))
        return publish(self.candidate, self.profiles, self.receipt,
                       self.publication, "trusted-test")

    def test_snapshots_and_repeated_submission(self):
        first = self.submit()
        original = self.publication / first["entry"]["original"]
        old_bytes = original.read_bytes()
        self.assertFalse(self.submit()["published"])
        self.payload["records"][0]["train"] = .95
        second = self.submit()
        self.assertEqual(second["entry"]["previous"], first["entry"]["path"])
        self.assertEqual(second["entry"]["original"], first["entry"]["path"])
        self.assertEqual(original.read_bytes(), old_bytes)

    def test_tampering_after_verification(self):
        self.submit()
        self.payload["records"][0]["train"] = .99
        self.candidate.write_text(json.dumps(self.payload))
        with self.assertRaises(ValueError):
            publish(self.candidate, self.profiles, self.receipt,
                    self.publication, "trusted-test")

    def test_concurrent_publication(self):
        self.submit()
        (self.publication / ".publication-lock").mkdir()
        with self.assertRaises(RuntimeError):
            self.submit()


if __name__ == "__main__":
    unittest.main()
