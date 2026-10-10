import json, unittest
from pathlib import Path
from regional_result_paths import result_paths, approved_paths

class PublicModelTests(unittest.TestCase):
    def setUp(self):
        base=Path(__file__).parent
        self.manifest=json.loads((base/'profiles.json').read_text())
        self.profiles=self.manifest['profiles']
        self.workers=json.loads((base/'worker/worker-config.json').read_text())['profiles']

    def test_all_eight_have_matching_enabled_workers(self):
        self.assertEqual({p['contract']['model'] for p in self.profiles},
                         {'hymod','hmodel','sacsma','Xinanjiang','gr4jA','hbv','cfe_nwm','user_model'})
        self.assertTrue(all(p['enabled'] for p in self.profiles))
        self.assertEqual({p['id'] for p in self.profiles},{p['id'] for p in self.workers})

    def test_distinct_model_files_shared_master(self):
        paths=[result_paths(p) for p in self.profiles]
        for col in (0,1,3):self.assertEqual(len({p[col] for p in paths}),8)
        self.assertEqual(len({p[2] for p in paths}),1)
        self.assertEqual(len(approved_paths(self.manifest)),25)

    def test_user_example_requires_definition_fingerprint(self):
        self.assertTrue(all(w['run']['model'] in [1,2,3,4,5,6,7,99] for w in self.workers))
        p=next(p for p in self.profiles if p['contract']['model']=='user_model')
        self.assertRegex(p['contract']['configuration'],r'definition:[0-9a-f]{64};')

    def test_path_injection_rejected(self):
        p=json.loads(json.dumps(self.profiles[0]));p['contract']['model']='../user_model'
        with self.assertRaises(ValueError):result_paths(p)

if __name__=='__main__':unittest.main()
