import copy,json,unittest
from validate_submission import validate
from test_publish_verified import PublicationTests
from test_validate_submission import ValidationTests

class RangeValidation(ValidationTests):
    def test_changed_range_allowed_with_exact_profile(self):
        r=self.payload['records'][0]
        r['parameterRange']={'id':2,'thMin':[0,0],'thMax':[2,2]}
        r['theta']=[1.5,1.5];r['normalized']=[.75,.75]
        self.assertTrue(validate(self.payload,self.manifest)['schema_valid'])

    def test_wrong_normalization_rejected(self):
        r=self.payload['records'][0]
        r['parameterRange']={'id':2,'thMin':[0,0],'thMax':[2,2]}
        with self.assertRaisesRegex(ValueError,'physical'):validate(self.payload,self.manifest)

    def test_invalid_bounds_rejected(self):
        r=self.payload['records'][0]
        r['parameterRange']={'id':2,'thMin':[0,0],'thMax':[0,2]}
        with self.assertRaisesRegex(ValueError,'bounds'):validate(self.payload,self.manifest)

class RangePublication(PublicationTests):
    def test_collision_and_bound_reuse(self):
        r=self.payload['records'][0]
        r['parameterRange']={'id':2,'thMin':[0,0],'thMax':[2,2]};r['normalized']=[.25,.25]
        first=self.submit()
        snap=json.loads((self.publication/first['entry']['path']).read_text())
        self.assertEqual(snap['records'][0]['parameterRange']['id'],2)
        r['train']=.95;r['parameterRange']['thMax']=[4,4];r['normalized']=[.125,.125]
        second=self.submit();snap=json.loads((self.publication/second['entry']['path']).read_text())
        self.assertEqual(snap['records'][0]['parameterRange']['id'],3)
        r['train']=.99;r['parameterRange']={'id':8,'thMin':[0,0],'thMax':[2,2]};r['normalized']=[.25,.25]
        third=self.submit();snap=json.loads((self.publication/third['entry']['path']).read_text())
        self.assertEqual(snap['records'][0]['parameterRange']['id'],2)
        self.assertEqual(len(snap['parameterRanges']),3)

if __name__=='__main__':unittest.main()
