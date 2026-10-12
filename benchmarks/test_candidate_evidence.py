import copy,unittest
from test_local_reference_receipt import LocalReferenceTests
class CandidateEvidenceTests(LocalReferenceTests):
    def setUp(self):
        super().setUp()
        self.payload['localReferenceCheck']['schema']=2
        rows=[{k:r[k] for k in ('basin','metric','train','evaluation')} for r in self.payload['records']]
        hashes={'schema':1,'algorithm':'sha256-input-v1','records':[{'basin':rows[0]['basin'],'sha256':'a'*64}]}
        self.payload['localReferenceCheck']['candidateRecords']=rows
        self.payload['localReferenceCheck']['inputFingerprints']=copy.deepcopy(hashes)
        self.manifest['profiles'][0]['inputFingerprints']=hashes
    def test_wrong_candidate_score(self):
        self.payload['localReferenceCheck']['candidateRecords'][0]['train']+=.01
        with self.assertRaises(ValueError):self.check()
    def test_wrong_input_hash(self):
        self.payload['localReferenceCheck']['inputFingerprints']['records'][0]['sha256']='b'*64
        with self.assertRaises(ValueError):self.check()
    def test_missing_candidate_evidence(self):
        self.payload['localReferenceCheck']['candidateRecords']=[]
        with self.assertRaises(ValueError):self.check()
    def test_missing_input_evidence(self):
        self.payload['localReferenceCheck']['inputFingerprints']['records']=[]
        with self.assertRaises(ValueError):self.check()
    def partial_reference(self):
        import json,hashlib
        baseline=json.loads(self.raw)
        baseline['records']=[r for r in baseline['records'] if r['metric']!='S_logp']
        self.raw=json.dumps(baseline).encode()
        proof=self.payload['localReferenceCheck']
        proof['snapshotSha256']=hashlib.sha256(self.raw).hexdigest()
        proof['records']=[r for r in proof['records'] if r['metric']!='S_logp']
    def test_partial_reference_with_full_candidate_and_input_evidence(self):
        self.partial_reference()
        self.assertEqual(self.check()['checked'],1)
    def test_partial_reference_still_requires_every_available_incumbent(self):
        self.partial_reference()
        self.payload['localReferenceCheck']['records'].pop()
        with self.assertRaises(ValueError):self.check()
    def test_new_metric_still_requires_owner_reference(self):
        self.partial_reference()
        self.payload['records'][0]['metric']='S_logp'
        self.payload['localReferenceCheck']['candidateRecords'][0]['metric']='S_logp'
        with self.assertRaises(ValueError):self.check()
    def test_partial_reference_rejects_legacy_evidence(self):
        self.partial_reference()
        proof=self.payload['localReferenceCheck'];proof['schema']=1
        del proof['candidateRecords'];del proof['inputFingerprints']
        with self.assertRaises(ValueError):self.check()
    def test_worse_candidate_evaluation_allowed(self):
        self.payload['records'][0].update(train=.95,evaluation=-2)
        self.payload['localReferenceCheck']['candidateRecords'][0].update(train=.95,evaluation=-2)
        self.assertEqual(self.check()['verified_records'][0]['evaluation'],-2)
    def test_publication_preserves_parameter_and_evaluation_pair(self):
        # Parent changes scores; supply their matching replay evidence first.
        self.payload['localReferenceCheck']['candidateRecords'][0].update(train=.95,evaluation=-2)
        super().test_publication_preserves_parameter_and_evaluation_pair()
if __name__=='__main__':unittest.main()
