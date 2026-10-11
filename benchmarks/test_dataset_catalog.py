import copy,json,unittest,hashlib
from test_candidate_evidence import CandidateEvidenceTests
class DatasetCatalogTests(CandidateEvidenceTests):
 def setUp(self):
  super().setUp()
  self.payload['contract'].update(resolution='daily',provenance={'region':'CAMELS_US','data':1,'pet':1},period='default')
  self.manifest['profiles'][0]['contract']=copy.deepcopy(self.payload['contract'])
  baseline=json.loads(self.raw);baseline['contract']=copy.deepcopy(self.payload['contract']);self.raw=json.dumps(baseline).encode();self.payload['localReferenceCheck']['snapshotSha256']=hashlib.sha256(self.raw).hexdigest()
  p=self.manifest['profiles'][0];hashes=p.pop('inputFingerprints')
  self.catalog={'schema':1,'algorithm':'sha256-input-v1','entries':[{'complete':True,'identity':{k:copy.deepcopy(self.payload['contract'][k]) for k in ('resolution','provenance','period')},'inputFingerprints':hashes}]}
  self.write_catalog()
 def write_catalog(self):
  (self.root/'inputs.json').write_text(json.dumps(self.catalog))
 def test_catalog_requires_exact_period(self):
  self.catalog['entries'][0]['identity']['period']='changed';self.write_catalog()
  with self.assertRaises(ValueError):self.check()
 def test_catalog_requires_exact_resolution(self):
  self.catalog['entries'][0]['identity']['resolution']='hourly';self.write_catalog()
  with self.assertRaises(ValueError):self.check()
 def test_catalog_requires_exact_region_and_forcing(self):
  self.catalog['entries'][0]['identity']['provenance']['region']='CAMELS_BE';self.write_catalog()
  with self.assertRaises(ValueError):self.check()
 def test_incomplete_registration_rejected(self):
  self.catalog['entries'][0]['complete']=False;self.write_catalog()
  with self.assertRaises(ValueError):self.check()
 def test_missing_catalog_rejected(self):
  (self.root/'inputs.json').unlink()
  with self.assertRaises(ValueError):self.check()
 def test_matlab_singleton_catalog(self):
  self.catalog['entries']=self.catalog['entries'][0];self.write_catalog();self.check()
if __name__=='__main__':unittest.main()
