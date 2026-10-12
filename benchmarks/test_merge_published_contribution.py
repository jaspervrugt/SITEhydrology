import os
import unittest
from unittest.mock import patch
import merge_published_contribution as merger


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.pr = {"state": "open", "head": {"sha": "verified"},
                   "base": {"ref": "main"}, "changed_files": 1, "draft": True}
        self.files = [{"filename": "benchmarks/inbox/" + "a" * 64 + ".json",
                       "status": "added"}]

    def test_changed_head_and_non_numerical_files_are_rejected(self):
        self.assertFalse(merger.eligible(self.pr, self.files, "new-head"))
        for filename in [".github/workflows/run.yml", "benchmarks/initial-inbox/" + "a" * 64 + ".json"]:
            self.assertFalse(merger.eligible(self.pr, [{"filename": filename, "status": "added"}], "verified"))
        self.assertFalse(merger.eligible(self.pr, [], "verified"))
        self.files[0]["status"] = "removed"
        self.assertFalse(merger.eligible(self.pr, self.files, "verified"))

    @patch.dict(os.environ, {"REPOSITORY": "owner/repo", "PR_NUMBER": "49", "EXPECTED_HEAD_SHA": "verified"})
    def test_draft_is_readied_and_merge_is_pinned_to_verified_head(self):
        with patch.object(merger, "api", side_effect=[self.pr, self.files, {"merged": True}]) as api, patch.object(merger.subprocess, "run") as run:
            merger.main()
        run.assert_called_once_with(["gh", "pr", "ready", "49", "--repo", "owner/repo"], check=True)
        self.assertEqual(api.call_args.args, ("repos/owner/repo/pulls/49/merge", "PUT", {"sha": "verified", "merge_method": "squash"}))

    @patch.dict(os.environ, {"REPOSITORY": "owner/repo", "PR_NUMBER": "49", "EXPECTED_HEAD_SHA": "changed"})
    def test_stale_job_does_not_ready_or_merge(self):
        with patch.object(merger, "api", side_effect=[self.pr, self.files]) as api, patch.object(merger.subprocess, "run") as run:
            merger.main()
        self.assertEqual(api.call_count, 2)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
