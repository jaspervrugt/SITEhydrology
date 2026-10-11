import json,unittest
from test_local_reference_receipt import LocalReferenceTests
from validate_submission import validate
from publish_verified import publish
class ResultCounterTests(LocalReferenceTests):
 def test_counter_round_trip(self):
  self.payload['records'][0].update(runCount=31,improvementCount=8,contributor='jaspervrugt',platform='Windows')
  receipt=self.check();p=self.root/'receipt.json';p.write_text(json.dumps(receipt))
  result=publish(self.root/'candidate.json',self.root/'profiles.json',p,self.root/'published','test-revision')
  snapshot=json.loads((self.root/'published'/result['entry']['path']).read_text())
  self.assertEqual(snapshot['records'][0]['runCount'],31);self.assertEqual(snapshot['records'][0]['improvementCount'],8)
  self.assertEqual(snapshot['records'][0]['contributor'],'jaspervrugt');self.assertEqual(snapshot['records'][0]['platform'],'Windows')
  again=publish(self.root/'candidate.json',self.root/'profiles.json',p,self.root/'published','test-revision')
  self.assertFalse(again['published'])
 def test_invalid_counts_rejected(self):
  for value in (-1,.5,True,float('nan')):
   for field in ('runCount','improvementCount'):
    with self.subTest(value=value,field=field):
     self.payload['records'][0][field]=value
     with self.assertRaises(ValueError):validate(self.payload,self.manifest)
     del self.payload['records'][0][field]
 def test_invalid_attribution_rejected(self):
  for field,value in (('contributor','user@example.com'),('contributor',''),('platform','LEGO-HORSE-2026')):
   self.payload['records'][0][field]=value
   with self.assertRaises(ValueError):validate(self.payload,self.manifest)
   del self.payload['records'][0][field]
if __name__=='__main__':unittest.main()
