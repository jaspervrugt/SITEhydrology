import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from local_reference_receipt import receipt, same_score
from publish_verified import publish
from test_validate_submission import ValidationTests


class LocalReferenceTests(unittest.TestCase):
    def setUp(self):
        fixture = ValidationTests(); fixture.setUp()
        self.payload, self.manifest = fixture.payload, fixture.manifest
        metrics = ['NSE','KGE','SAR','RSS','Huber','JKGE','S_fdc','S_p','S_logp']
        self.payload['contract']['metrics'] = metrics
        self.manifest['profiles'][0]['contract']['metrics'] = metrics
        self.payload['contract']['maximize'] = [True]*len(metrics)
        self.manifest['profiles'][0]['contract']['maximize'] = [True]*len(metrics)
        refs = []
        for metric in metrics:
            r = copy.deepcopy(self.payload['records'][0]); r['metric'] = metric
            refs.append(r)
        self.raw = json.dumps({'profile':'test','contract':self.payload['contract'],
                               'records':refs}).encode()
        self.payload['localReferenceCheck'] = {
            'schema':1,'mode':'local_reference','snapshotSha256':hashlib.sha256(self.raw).hexdigest(),
            'records':[{k:r[k] for k in ('basin','metric','train','evaluation')} for r in refs]}
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def check(self):
        candidate, manifest = self.root/'candidate.json', self.root/'profiles.json'
        candidate.write_text(json.dumps(self.payload)); manifest.write_text(json.dumps(self.manifest))
        return receipt(candidate,manifest,self.raw,'test-revision')

    def test_all_objectives_match(self):
        result = self.check()
        self.assertEqual(result['verification_mode'],'local_reference')
        self.assertEqual(result['checked'],1)

    def test_worse_candidate_evaluation_allowed(self):
        self.payload['records'][0].update(train=.95,evaluation=-2)
        self.assertEqual(self.check()['verified_records'][0]['evaluation'],-2)

    def test_changed_training_reference_rejected(self):
        self.payload['localReferenceCheck']['records'][4]['train'] += .01
        with self.assertRaises(ValueError): self.check()

    def test_changed_evaluation_reference_rejected(self):
        self.payload['localReferenceCheck']['records'][7]['evaluation'] += .01
        with self.assertRaises(ValueError): self.check()

    def test_incomplete_objectives_rejected(self):
        self.payload['localReferenceCheck']['records'].pop()
        with self.assertRaises(ValueError): self.check()

    def test_missing_proof_rejected(self):
        del self.payload['localReferenceCheck']
        with self.assertRaises(ValueError): self.check()

    def test_wrong_snapshot_rejected(self):
        self.payload['localReferenceCheck']['snapshotSha256'] = '0'*64
        with self.assertRaises(ValueError): self.check()

    def test_duplicate_evidence_rejected(self):
        self.payload['localReferenceCheck']['records'][1] = self.payload['localReferenceCheck']['records'][0]
        with self.assertRaises(ValueError): self.check()

    def test_tolerance_and_missing_values(self):
        self.assertTrue(same_score(.9+1e-8,.9))
        self.assertFalse(same_score(.9001,.9))
        self.assertTrue(same_score(None,None))
        self.assertFalse(same_score(None,.9))
        self.assertFalse(same_score(True,1))

    def test_publication_preserves_parameter_and_evaluation_pair(self):
        self.payload['records'][0].update(train=.95,evaluation=-2,theta=[.6,.6],normalized=[.6,.6])
        checked = self.check()
        path = self.root/'receipt.json'; path.write_text(json.dumps(checked))
        result = publish(self.root/'candidate.json',self.root/'profiles.json',path,
                         self.root/'published','test-revision')
        snapshot = json.loads((self.root/'published'/result['entry']['path']).read_text())
        self.assertEqual(snapshot['verificationMode'],'local_reference')
        self.assertEqual(snapshot['records'][0]['theta'],[.6,.6])
        self.assertEqual(snapshot['records'][0]['evaluation'],-2)


if __name__ == '__main__': unittest.main()
