import copy
import unittest
from validate_submission import validate


class ValidationTests(unittest.TestCase):
    def setUp(self):
        contract = {"thMin": [0, 0], "thMax": [1, 1], "metrics": ["NSE"]}
        self.manifest = {"profiles": [{"id": "test", "enabled": True,
                                      "contract": contract, "basinIds": ["A"]}]}
        record = {"basin": "A", "metric": "NSE", "train": .9,
                  "evaluation": .8, "theta": [.5, .5], "normalized": [.5, .5],
                  "optimizedLoss": "NSE", "optimizer": 1, "runtime": 10,
                  "updated": "2026-10-08T12:00:00"}
        self.payload = {"schema": 1, "origin": "SITE_compiled_GUI",
                        "contract": copy.deepcopy(contract), "profile": "test",
                        "records": [record]}

    def test_valid_is_not_publishable(self):
        report = validate(self.payload, self.manifest)
        self.assertTrue(report["schema_valid"])
        self.assertFalse(report["publication_allowed"])

    def test_duplicate(self):
        self.payload["records"] *= 2
        with self.assertRaises(ValueError):
            validate(self.payload, self.manifest)

    def test_changed_contract(self):
        self.payload["contract"]["thMax"][0] = 1e10
        with self.assertRaises(ValueError):
            validate(self.payload, self.manifest)

    def test_out_of_bounds(self):
        self.payload["records"][0]["theta"][0] = 2
        with self.assertRaises(ValueError):
            validate(self.payload, self.manifest)

    def test_origin_is_not_proof(self):
        self.payload["origin"] = "forged GUI claim"
        self.assertFalse(validate(self.payload, self.manifest)["publication_allowed"])

    def test_no_profile(self):
        with self.assertRaises(ValueError):
            validate(self.payload, {"profiles": []})


if __name__ == "__main__":
    unittest.main()
