import copy,unittest
from local_reference_receipt import contract_identity
class EmptySelectors(unittest.TestCase):
 def test_unused_selectors(self):
  a={'period':'default','provenance':{'precip':None,'temp':None,'data':3}}
  b=copy.deepcopy(a);b['provenance'].update(precip=[],temp=[])
  self.assertEqual(contract_identity(a),contract_identity(b))
  self.assertEqual(a['provenance']['precip'],None)
 def test_actual_choices_stay_exact(self):
  a={'period':'default','provenance':{'precip':None,'temp':None,'data':3}}
  for key in ('precip','temp','data'):
   b=copy.deepcopy(a);b['provenance'][key]=1
   self.assertNotEqual(contract_identity(a),contract_identity(b))
  b=copy.deepcopy(a);b['period']='changed';self.assertNotEqual(contract_identity(a),contract_identity(b))
if __name__=='__main__':unittest.main()
