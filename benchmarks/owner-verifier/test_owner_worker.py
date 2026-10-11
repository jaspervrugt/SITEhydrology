import copy,hashlib,json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parent/'lib'))
from validate_initial import validate_initial
import owner_worker as worker
ROOT=Path(__file__).resolve().parents[2]

class InitialTests(unittest.TestCase):
 def setUp(self):
  fixture=ROOT/'benchmarks/tests/hbv_candidate.json'
  if not fixture.exists():fixture=ROOT/'.codex-work/site-parameter-ranges/benchmarks/tests/hbv_candidate.json'
  p=json.loads(fixture.read_text());p['records']=p['records'][:1]
  self.envelope={'schema':1,'kind':'owner_initial_reference','payload':p,'inputFingerprints':{'schema':1,'algorithm':'sha256-input-v1','records':[{'basin':p['records'][0]['basin'],'sha256':'1'*64}]}}
 def test_structural_only(self):self.assertEqual(validate_initial(self.envelope)['records'],1)
 def test_missing_hash(self):
  self.envelope['inputFingerprints']['records']=[]
  with self.assertRaises(ValueError):validate_initial(self.envelope)
 def test_changed_hash_shape(self):
  self.envelope['inputFingerprints']['records'][0]['sha256']='bad'
  with self.assertRaises(ValueError):validate_initial(self.envelope)
 def test_duplicate_hash(self):
  self.envelope['inputFingerprints']['records']*=2
  with self.assertRaises(ValueError):validate_initial(self.envelope)
 def test_uncovered_basin(self):
  self.envelope['inputFingerprints']['records'][0]['basin']='other'
  with self.assertRaises(ValueError):validate_initial(self.envelope)
 def test_code_rejected(self):
  for path in ('benchmarks/owner-verifier/owner_worker.py','benchmarks/initial-inbox/../../bad.json','benchmarks/inbox/'+'1'*64+'.json'):
   with self.assertRaises(ValueError):worker.proposal_files([{'filename':path,'status':'added'}])
 def test_rename_rejected(self):
  with self.assertRaises(ValueError):worker.proposal_files([{'filename':'benchmarks/initial-inbox/'+'1'*64+'.json','status':'renamed'}])
 def test_owner_code_changes_block(self):
  with tempfile.TemporaryDirectory() as tmp:
   f=Path(tmp)/'trusted.m';f.write_text('trusted code');c={'trustedFiles':[{'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}]};worker.source_revision(c);f.write_text('changed code')
   with self.assertRaises(RuntimeError):worker.source_revision(c)
 def test_site_open_defers_everything(self):
  with patch.object(worker,'site_open',return_value=True),patch.object(worker,'api') as api:
   self.assertEqual(worker.run({})['state'],'waiting');api.assert_not_called()
 def test_matlab_quote(self):self.assertEqual(worker.quote("a'b"),"'a''b'")
 def test_singleton_hash_preserves_prior(self):
  old={'id':'test','contract':{},'enabled':True,'basinIds':['1','2'],'inputFingerprints':{'records':{'basin':'1','sha256':'a'*64}}}
  new=dict(old,inputFingerprints={'records':{'basin':'2','sha256':'b'*64}})
  merged=worker.uniform_profiles({'profiles':[old]},new)
  self.assertEqual(len(merged['profiles'][0]['inputFingerprints']['records']),2)
 def test_new_profile_uniform_fields(self):
  old={'id':'old','enabled':True,'contract':{},'inputFingerprints':{},'inputFingerprintSource':'owner','legacyAttribution':{'contributor':'jaspervrugt','platform':'Windows'}}
  new={'id':'new','enabled':True,'contract':{},'inputFingerprints':{}}
  rows=worker.uniform_profiles({'profiles':[old]},new)['profiles'];self.assertEqual(set(rows[0]),set(rows[1]));self.assertEqual(rows[1]['legacyAttribution']['contributor'],'Unknown')
 def test_live_lock_not_removed(self):
  with tempfile.TemporaryDirectory() as tmp:
   lock=Path(tmp)/'lock';lock.mkdir();(lock/'pid.json').write_text('{"pid":1}')
   with patch.object(worker,'process_running',return_value=True):self.assertFalse(worker.acquire_lock(lock))
   self.assertTrue(lock.exists())
 def test_rebooted_worker_lock_recovered(self):
  with tempfile.TemporaryDirectory() as tmp:
   lock=Path(tmp)/'lock';lock.mkdir();(lock/'pid.json').write_text('{"pid":1}')
   with patch.object(worker,'process_running',return_value=False):self.assertTrue(worker.acquire_lock(lock))
   self.assertNotEqual(json.loads((lock/'pid.json').read_text())['pid'],1)

if __name__=='__main__':unittest.main()
